# The Graphics Scientist
*There's no magic here*

![GIF Demo](https://github.com/blondie7575/GraphicsScientist/blob/main/SampleCode/SpriteDemo.gif)


## Introduction
The Graphics Scientist is a tool for building sprites and other image data for Apple II games. One of the primary challenges for new developers on the platform is figuring out the crazy hi-res video memory layout. Once you manage that, you then have to figure out how to get artwork into some sort of tortured byte layout that will look correct when copied into the aforementioned video memory. This tool won't help you learn Apple Hi-Res (I recommend [Roger Wagner's book](https://archive.org/details/AssemblyLinesCompleteWagner) for that). However it will help you with that tortured byte problem. We're all about the tortured bytes here.

In a nutshell, this tool reads a PNG, finds sprites in it, generates all seven pre-shifts of that sprite, and outputs data and lookup tables for you to use in your code. It also generates tables for division/modulous by seven which you will need for rendering. 


## How It Works
The Graphics Scientist is a Python script that can (among other things) take a PNG file from your favourite art package, extract sprites from it, then give you the byte patterns to be copied into video memory. The output can either be text, in which case you can cut and paste it into your source code. Alternatively the output can be binary, in which case you'll get a file which can be put on your disk image and loaded into RAM by your loader. It does its best to intepret your supplied PNG file into something that can be rendered by an Apple II. More details on this below.

## The Demo

Included in this repository is a sample PNG with a running-man animation (who may or may not be recently retired from a certain Bungling Empire). The little man demonstrates a typical usage of an animated moving sprite. There's also a large multicolour graphic that demonstrates basic image rendering for titles and such. There's a sample sprite geometry file, and a sample program that shows the most basic possible way to render sprites and title images produced by TGS.

## Creating Your Artwork

The Apple II has only four colours in the basic Hi-Res mode (not counting the two blacks and two whites). These colours are generally referred to as Magenta, Green, Orange, and Blue. However, there are also two "palettes". Only green/magenta can co-exist within one byte, and only orange/blue can co-exist within one byte. Each byte holds 3.5 pixels and a palette bit, more or less (it depends somewhat how you interpret and render the bits).

Your PNG file can contain any number of sprites, animation frames, and other images to be rendered. You will provide a "geometry" file that tells TGS where each graphic is in the file. You can use whatever colours you like, but TGS will try and map them to white, black, magenta, green, orange, and blue. See the included sample PNG for recommended RGB values to use for best matches.

**IMPORTANT**: The PNG file *must not have an alpha channel*. Many art programs produce alpha channels by default for PNG files. Make sure yours is configured to not do this.

![Sample art](https://github.com/blondie7575/GraphicsScientist/blob/main/SampleCode/SpriteSheet.png)

## Resolutions

A row of video memory in the Apple II is really a continuous stream of bits that bit-bang an analog NTSC waveform. You can interpret those bits as 280 monochrome pixels (one bit each) with artifact colours happening around and between those pixels. Alternatively, you can interpret a row as 140 pixels of two bits each, and you can guarantee a solid colour on each pixel, at the cost of lower effective resolution. Both approaches have advantages and use-cases, so TGS supports both. You can even mix and match resolutions within your PNG.

## Running The Tool

Before you can use the graphics data, you should run the tool once to generate the lookup tables needed for basic Apple II sprite rendering:

`./GraphicsScientist.py -t `

The -t (or --tables) option spits out all the lookup tables you need for rendering, which can be copied into your code. All code produced by TGS uses ca65 syntax. I am sorry if that angers you. But not very sorry.

Next you are ready to generate your graphics data. The easiest way for beginners and most use cases will be the text option:

`./GraphicsScientist.py -g SpriteGeometry.txt SpriteSheet.png`

You provide the name of your geometry file with the -g (or --geometry) option, and you finish with the name of your PNG file.

The text output you will get looks like this for a basic sprite:


```
runFrame0:
	.byte $02,$0d		; Width in bytes, Height
	.addr runFrame0_Shift0
	.addr runFrame0_Shift1
	.addr runFrame0_Shift2
	.addr runFrame0_Shift3
	.addr runFrame0_Shift4
	.addr runFrame0_Shift5
	.addr runFrame0_Shift6

runFrame0_Shift0:
	.byte	$40,$00,$60...
runFrame0_Shift1:
	.byte	$00,$01,$40...
runFrame0_Shift2:
	.byte	$00,$02,$00...
runFrame0_Shift3:
	.byte	$00,$04,$00...
runFrame0_Shift4:
	.byte	$00,$08,$00...
runFrame0_Shift5:
	.byte	$00,$10,$00...
runFrame0_Shift6:
	.byte	$00,$20,$00...
```

(Byte data truncated here for clarity)

The top is a little struct that has the width and height of the sprite, followed by a lookup table to each of the "shifts". In Apple II hi-res graphics, rendering a sprite on a specific pixel requires a lot of math because there are 3.5 pixels per byte. Every fourth pixel is split across two bytes, and the amount of bit-shift needed when you copy bytes varies by which horizontal pixel you want your sprite to be on. This is a lot of expensive math (involving a lot of dividing and modulous of seven), but there's a better way. You can simply store seven copies of your sprite, each "pre-shifted" within the bytes to land on the correct pixels. This way your blitting is always byte-aligned (and fast), but you can still place your artwork on any pixel. TGS creates these shifts for you, and provides a lookup table for you to choose the correct one in your blitter at runtime. Here's an example of using that lookup table.

First we figure out which starting byte the sprite will land based on the desired horizontal pixel. This requires dividing by seven, for which we use the first lookup table provided by TGS.

```blitSprite:
	ldy RENDERPOS_X			; Calculate horizontal byte to render on
	lda (DIV7TABLE_L),y
	sta RENDER_BYTEX
```

Next we need to choose the right shifted sprite based on the bit within that byte that our pixel lands on. That requires a modulous of seven, for which we use the other TGS-provided table.

```	ldy RENDERPOS_X			
	lda hiResRowsMod7,y
	tay
	iny				; Skip dimensions to get to lookup table
	iny
	lda (SPRITEPTR_L),y
	sta PIXELPTR_L
	iny
	lda (SPRITEPTR_L),y
	sta PIXELPTR_H
```

PIXELPTR_L/H now points to the pixels of the correct shifted sprite. If we copy those to the screen starting at RENDER_BYTEX, our sprite will magically appear on the exact pixel we wanted, while only doing very cheap byte copies.

_Side Note:_ None of this is my brilliant idea. This "preshifting" approach to sprites is how most really fast Apple II games were done, especially in the latter years when more and more developers had figured this out. I'm not inventing anything here, just explaining how it's done for anyone who might be new. I'm not just standing on the shoulders of giants, I am standing on the ground, pointing upwards, and describing their amazing shoulders to you.

Be sure to refer to the included sample code to see all of that in context. These little snippets are obviously glossing over some details, but you get the idea.

## The Sprite Geometry File

This a simple CSV file which you provide to TGS to tell it where all your sprites are in the PNG, and what kind of options you'd like for each one. Here is the sample included:

```
runFrame0,1,1,9,13,280,6,0
runFrame1,17,1,9,13,280,6,0
runFrame2,33,1,9,13,280,6,0
runFrame3,50,1,9,13,280,6,0
helloWorld,0,24,87,10,140,0,A
```
Left to right, the fields are:

1) A name for the sprite, to be used in code (text output mode only)
2) The X position (in pixels) of the top left corner of the sprite or image
3) The Y position (in pixels) of the top left corner of the sprite or image
4) The width (in pixels) of the sprite or image
5) The height (in pixels) of the sprite or image
6) The desired resolution (140 or 280) of this image. More on this below
7) The number of shifts you desire for this image (usually 0 or 6)
8) The desired high bit algorithm for this image. See below.

### Resolution

Each sprite can be interpreted as 280 or 140 horizontal pixel resolution. This determines whether a pixel in the PNG is mapped to one or two bits. 140 mode gives you good control of colour, in the sense that you will get an orange pixel where you want one, with no weird half-purple pixels around it (or whatever other insanity the Apple II will do to your art). However if you're skilled with Apple II art, you can achieve the look you want with only 1-bit per pixel and careful fudging of artifact colours. Most of the time you'll use 280 mode with monochrome artwork (such as the running man in the sample) but dithering patterns of black and white pixels can be used to create many effects. All pixels in the PNG will be interpreted as black or white only in 280 mode. What it looks like at run time is up to exactly how you blit it. The details of this are deep Apple II lore and beyond the scope of this document. For more complex colour sprites and title artwork, you'll probably want 140 mode.

### Shifts

For most things that move in your game (enemies, players, etc) you'll want six shifts. You want to make sure you can render everything on every pixel. For static title cards, score screens, etc, you don't need any shifts, so set this to zero (and plan to byte-align that artwork when you render it). You wouldn't want shifts for title art because it would take a lot of RAM and there's no need for pixel-accurate alignment of this sort of thing.

### High Bit Algorithm

The bane of every Apple II graphics developer is the high bit. Each byte on the graphics page has a "palette" bit at bit 7. This is not a pixel and does not render. It actually creates a 90º phase shift in the NTSC signal for that byte, causing green and magenta to turn into orange  and blue. Thus why it acts like a "palette" selection and why certain colours cannot co-exist in the same byte. This is difficult to manage, so TGS gives you a bunch of options to use in the geometry file:
- 0 : The high bit will be clear for this entire sprite. Use this if you're happy using only magenta and green in this specific sprite.
- 1  : The high bit will be set for this entire sprite. Use this if you're happy using only orange and blue in this specific sprite. 
- F : The high bit will be set the same for each row of the sprite, and will be chosen by the first pixel on that row of the sprite. If the first pixel is green or magenta, that entire row will be high bit clear (and vice-versa). This allows you to use all four colours in one sprite, you just can't mix green/orange or magenta/blue on one row. Note that black and white are available in both palettes.
- A : This is an automatic mode that attempts to choose a high bit unique to every byte in your artwork. This will never be perfect, because it requires you to align your colour changes with 3.5 pixel boundaries, which requires some next level Apple II art-fu to achieve. However it can be done, and TGS will scan the pixels of each byte and choose a high bit that best matches the colours in that byte. The sample code displays Hello World using this mode, and you can see the approximation in action. It does pretty well at matching the original PNG artwork, but obviously this is a very fraught method that won't be reliable in many cases. You should probably not bother with this mode, but I wanted to try it so here it is.

## Binary Mode

I've been talking about text mode up until now because it's generally the most useful (in my opinion). However you can also generate binary data with the -b (or --binary) flag:

`/GraphicsScientist.py -b MYGFX -g SpriteGeometry.txt SpriteSheet.png`

That will create a binary file called MYGFX that has the same data as the text output, _but without the lookup tables for shifts_. There's no way for TGS to know where you're going to load this in RAM, so the data is provided in a more compact format that maps to this (if it were text mode):

```
runFrame0:
	.byte $02,$0d		; Width in bytes, Height
runFrame0_Shift0:
	.byte	$40,$00,$60...
runFrame0_Shift1:
	.byte$00,$01,$40...
runFrame0_Shift2:
	.byte	$00,$02,$00...
runFrame0_Shift3:
	.byte	$00,$04,$00...
runFrame0_Shift4:
	.byte	$00,$08,$00...
runFrame0_Shift5:
	.byte	$00,$10,$00...
runFrame0_Shift6:
	.byte	$00,$20,$00...
```
As you can see, it's the same data, without the lookup table. It's up to you to build the lookup table or otherwise determine how to look up the pointers to the shifts in your code. However the really hard work of generating all the shifted sprite data is still done for you, so it's hard to complain too much. Someone will, no doubt, but here we are.


## Conclusion

That's it! This is a tool that I desperately wanted for my own Apple II development efforts, so I thought I would write it and put it out there. Maybe other people would find this useful as well, and perhaps it will encourage more Apple II development. If you made it this far, thanks for reading!


