#!/usr/bin/env python3

import sys,os,png,csv,argparse

class Colors:
	black,magenta,green,orange,blue,white,key = range(7)

class HighBitMode:
	high,low,first,auto = range(4)
	

def main(argv):
	parser = argparse.ArgumentParser(description="Sprite generator for creating all shifts of the given sprite")
	parser.add_argument("-g", "--geometry", help="A CSV file with geometry of each sprite in the PNG. One sprite per line.\nFormat is (x,y,w,h,resolution,shifts)")
	parser.add_argument("-b", "--binary", default="", help="A filename to write the binary data out to")
	parser.add_argument("-t", "--tables", action="store_true", default=False, help="output only lookup tables for horizontal sprite shifts (division and modulus 7)")
	parser.add_argument("files", nargs="*", help="a PNG image [or a list of them]. PNG files must not have an alpha channel!")
	options, extra_args = parser.parse_known_args()

	if options.tables:
		printHorizontalTables()
		exit(0)
	
	spriteGeometry = list()
	with open(options.geometry, newline='') as csvfile:
		reader = csv.reader(csvfile, delimiter=',', quotechar='|')
		for row in reader:
			spriteGeometry.append(row)

	for pngfile in options.files:
		process(pngfile,spriteGeometry,options.binary)
	

def process(pngfile,geometry,binaryFile):
	reader = png.Reader(pngfile)
	try:
		pngdata = reader.asRGB8()
	except:
		usage()

	pixels = list(pngdata[2])
	
	for record in geometry:
		name = record[0]
		posx = int(record[1])
		posy = int(record[2])
		width = int(record[3])
		height = int(record[4])
		mono = False
		if int(record[5]) == 280:
			mono = True
		shiftCount = int(record[6])
		highMode = highBitModeFromString(record[7])
		
		if binaryFile == "":
			processSpriteText(posx,posy,width,height,mono,pixels,name,shiftCount,highMode)
		else:
			processSpriteBinary(posx,posy,width,height,mono,pixels,name,shiftCount,highMode,binaryFile)
	
	
def processSpriteText(originX,originY,width,height,mono,pixelData,niceName,shiftCount,highMode):

	# Jump table
	byteWidth = calcByteWidth(width,mono)
	print ("%s:" % niceName)
	print ("\t.byte $%02x,$%02x\t\t; Width in bytes, Height" % (byteWidth,height))
	
	if shiftCount>0:
		for shift in range(0,shiftCount+1):
			print("\t.addr %s_Shift%d" % (niceName,shift))
		print("")
	
	# Bit patterns for shifts
	for shift in range(0,shiftCount+1):
		if shiftCount>0:
			print ("%s_Shift%d:\n\t.byte\t" % (niceName,shift), end="")
		else:
			print ("\t.byte\t", end="")
						
		spriteChunks = byteStreamsFromPixels(pixelData,originX,originY,width,height,shift,bitsForColor,highBitForColor,mono,highMode)
		
		byteCount=0
		for row in range(height):
			for byte in range(len(spriteChunks[row])):
			
				realByte = int(spriteChunks[row][byte], base=2)
				print ("$%02x" % (realByte), end="")
				
				byteCount = byteCount+1
				if byteCount == 32:
					print("\n\t.byte\t",end="")
					byteCount=0
				elif (byte != len(spriteChunks[row])-1) or (row!=height-1):
					print (",", end="")
					
		print ("")


def processSpriteBinary(originX,originY,width,height,mono,pixelData,niceName,shiftCount,highMode,binaryFile):

	outputData = bytearray()
	
	# Header
	byteWidth = calcByteWidth(width,mono)
	outputData.append(byteWidth)
	outputData.append(height)
			
	# Bit patterns for shifts
	for shift in range(0,shiftCount+1):
		spriteChunks = byteStreamsFromPixels(pixelData,originX,originY,width,height,shift,bitsForColor,highBitForColor,mono,highMode)
		
		for row in range(height):
			for byte in range(len(spriteChunks[row])):
			
				realByte = int(spriteChunks[row][byte], base=2)
				outputData.append(realByte)
						
	with open(binaryFile, "ab") as binary_file:
		binary_file.write(outputData)
		
		
    
def calcByteWidth(pixelWidth,mono):
	if mono:
		byteWidth = int(pixelWidth/7+1)
	else:
		byteWidth = int(pixelWidth/3.5+1)

	return byteWidth
	
	
def byteStreamsFromPixels(pixelData,originX,originY,width,height,shift,bitDelegate,highBitDelegate,mono,highMode):

	byteStreams = ["" for x in range(height)]
	byteWidth = calcByteWidth(width,mono)
	
	for row in range(height):
		bitStream = ""
		
		# Compute raw bitstream for row from PNG pixels
		for pixelIndex in range(width):
			pixel = pixelColor(pixelData,row+originY,pixelIndex+originX)
			bitStream += bitDelegate(pixel,mono)
		
		# Shift bit stream as needed
		bitStream = shiftStringRight(bitStream,shift,mono)
		bitStream = bitStream[:byteWidth*8]
		
		# Split bitstream into bytes
		bitPos = 0
		byteSplits = [0 for x in range(byteWidth)]
		
		rowPixelIndex = 0
		for byteIndex in range(byteWidth):
			remainingBits = len(bitStream) - bitPos
				
			bitChunk = ""
			
			if remainingBits < 0:
				bitChunk = "0000000"
			else:	
				if remainingBits < 7:
					bitChunk = bitStream[bitPos:]
					bitChunk += fillOutByte(7-remainingBits)
				else:	
					bitChunk = bitStream[bitPos:bitPos+7]				
			
			bitChunk = bitChunk[::-1]
			
			# Determine palette bit
			highBit = highBitDelegate(pixelData,row+originY,int(rowPixelIndex),originX,mono,highMode)
			byteSplits[byteIndex] = highBit + bitChunk
			bitPos += 7
			rowPixelIndex += 3.5

			
		byteStreams[row] = byteSplits;

	return byteStreams


def fillOutByte(numBits):
	filler = ""
	for bit in range(numBits):
		filler += "0"
	
	return filler


def shiftStringRight(string,shift,mono):
	if shift==0:
		return string
	
	if mono==False:
		shift *=2
	
	result = ""
	
	for i in range(shift):
		result += "0"
		
	result += string
	return result
				

def bitsForColor(pixel,mono):
	if mono:
		if pixel != Colors.black:
			return "1"
		return "0"
		
	if pixel == Colors.black:
		return "00"
	else:
		if pixel == Colors.white:
			return "11"
		else:
			if pixel == Colors.green or pixel == Colors.orange:
				return "01"

	# blue or magenta
	return "10"


def highBitForColor(pixelData,rowIndex,pixelIndex,rowStart,mono,mode):

	if mono or mode==HighBitMode.low:
		return "0"

	if mode==HighBitMode.high:
		return "1"
		
	if mode==HighBitMode.auto:		# Attempt to guess best high bit based on most colours in the byte
		highVotes = 0
		lowVotes = 0
		
		for i in range(pixelIndex,pixelIndex+4):
			pixel = pixelColor(pixelData,rowIndex,i)
			
			if pixel == Colors.orange or pixel == Colors.blue:
				highVotes += 1
			elif pixel == Colors.green or pixel == Colors.magenta:
				lowVotes += 1

		if highVotes>lowVotes:
			return "1"
			
		return "0"

	if mode==HighBitMode.first:		# Pick high bit based on first colour in the row
		pixel = pixelColor(pixelData,rowIndex,rowStart)
		if pixel == Colors.orange or pixel == Colors.blue:
			return "1"
			
	return "0"
	
	
				
def highBitModeFromString(input):
	if input=="A":
		return HighBitMode.auto
	if input=="1":
		return HighBitMode.high
	if input=="F":
		return HighBitMode.first
		
	return HighBitMode.low
	

def pixelColor(pixelData,row,col):
	r = pixelData[row][col*3]
	g = pixelData[row][col*3+1]
	b = pixelData[row][col*3+2]
	color = Colors.black
	
	if r>128 and g<128 and b>128:
		color = Colors.magenta
	else:
		if r<128 and g>128 and b<128:
			color = Colors.green
		else:
			if r<128 and g<128 and b>128:
				color = Colors.blue
			else:
				if r>128 and g<200 and b<128:		# Allow some green so it looks orange in PNG
					color = Colors.orange
				else:
					if r>128 and g>128 and b>128:
						color = Colors.white
					
	return color
	

def printHorizontalTables():
	
	print ("hiResRowsDiv7_2:",end="")
	
	index=0
	for pixel in range(140):
		if index==0:
			print ("\n\t.byte: ", end="")
		print ("$%02x" % (int(pixel / 7)*2), end="")
		if index<6:
			print (",", end="")
			index +=1
		else:
			index = 0
			
	index=0
	print ("\n\nhiResRowsDiv7:", end="")
	for pixel in range(280):
		if index==0:
			print ("\n\t.byte: ", end="")
		print ("$%02x" % (int(pixel / 7)), end="")
		if index<6:
			print (",", end="")
			index +=1
		else:
			index = 0
			
	index=0
	print ("\n\nhiResRowsMod7:", end="")
	for pixel in range(280):
		if index==0:
			print ("\n\t.byte: ", end="")
		print ("$%02x" % (int(pixel % 7)*2), end="")
		if index<6:
			print (",", end="")
			index +=1
		else:
			index = 0

	print("")
	
if __name__ == "__main__":
	main(sys.argv[1:])
	
