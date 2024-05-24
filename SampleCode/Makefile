#
#  Makefile
#  Tower Escape game
#
#  Created by Quinn Dunki on May 5, 2024
#  https://blondihacks.com
#


CL65=cl65
CAD=./cadius
ADDR=800
LOADERADDR=800
VOLNAME=SPRITEDEMO
IMG=DiskImageParts
PGM=spritedemo
EXECNAME=SPRITEDEMO\#060800

all: clean diskimage $(PGM) emulate

$(PGM):
	@PATH=$(PATH):/usr/local/bin; $(CL65) -C linkerConfig -t apple2 --start-addr $(ADDR) -l$(PGM).lst $(PGM).s -o $(EXECNAME)
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) $(EXECNAME)
	rm -f $(PGM).o
	rm -f $(PGM).lst
	rm -f $(EXECNAME)

diskimage:
	$(CAD) CREATEVOLUME $(VOLNAME).po $(VOLNAME) 143KB
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) $(IMG)/PRODOS/PRODOS#FF0000
	$(CAD) ADDFILE $(PGM).po /$(VOLNAME) $(IMG)/BASIC.SYSTEM/BASIC.SYSTEM#FF2000

clean:
	rm -f $(PGM)
	rm -f $(PGM).o
	rm -f $(PGM).lst
		
emulate:
		osascript V2Make.scpt $(PROJECT_DIR) $(VOLNAME)
	
