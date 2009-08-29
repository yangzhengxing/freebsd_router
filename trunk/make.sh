#!/bin/sh
#
# Make script for BSD Router Project 
#
# Copyright (c) 2009, The BSDRP Development Team 
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

#############################################
############ Variables definition ###########
#############################################

# Uncomment for enable debug: 
#set -x

# Exit if error
#set -e

FREEBSD_SRC=/usr/src
NANOBSD_DIR=/usr/src/tools/tools/nanobsd
BSDRP_VERSION=`cat ${NANOBSD_DIR}/BSDRP/Files/etc/BSDRP.version`

#Compact flash database needed for NanoBSD ?
#cp $NANOBSD_DIR/FlashDevice.sub .

# Progress Print level
PPLEVEL=3

#############################################
########### Function definition #############
#############################################

# Progress Print
#       Print $2 at level $1.
pprint() {
    if [ "$1" -le $PPLEVEL ]; then
        printf "%.${1}s %s\n" "#####" "$2"
    fi
}

#### Check current dir
check_current_dir() {
	if [ "${NANOBSD_DIR}/BSDRP" != `pwd` ]; then
		pprint 1 "You need to install BSDRP source code in ${NANOBSD_DIR}/BSDRP"
		exit 1
	fi
}

#### Check prerequisites
check_system() {
	pprint 3 "Checking if FreeBSD sources are installed..."
	SRC_VERSION=0
	if [ ! -f ${FREEBSD_SRC}/sys/conf/newvers.sh ]; then
		pprint 1 "ERROR: Can't found FreeBSD sources!"
		exit 1
	fi
		
	grep -q 'REVISION="8.0"' ${FREEBSD_SRC}/sys/conf/newvers.sh
	if [ $? -eq 0 ]; then
		SRC_VERSION="8.0"
	fi
	grep -q 'REVISION="7.2"' ${FREEBSD_SRC}/sys/conf/newvers.sh
	if [ $? -eq 0 ]; then
    	SRC_VERSION="7.2"
	fi

	if [ ${SRC_VERSION} = 0 ]; then
		pprint 1 "ERROR: BSDRP need FreeBSD 8.0 or 7.2 sources"
		pprint 1 "Read HOW TO here:"
		pprint 1 "http://bsdrp.net/documentation/technical_docs"
		exit 1
	fi
	pprint 3 "Will generate a BSDRP image based on FreeBSD ${SRC_VERSION}"
	pprint 3 "Checking if ports sources are installed..."

	if [ ! -d /usr/ports/net/quagga ]; then
		pprint 1 "ERROR: BSDRP need up-to-date FreeBSD ports sources tree"
		pprint 1 "And it seems that you didn't install the ports source tree"
        pprint 1 "Read HOW TO here:"
        pprint 1 "http://bsdrp.net/documentation/technical_docs"
		exit 1
	fi
}

###### Adding patch to NanoBSD
system_patch() {
	# Adding BSDRP label patch to NanoBSD
	# NanoBSD image use fixed boot disk: ad0, da0, etc...
	# This is a big limitation for a "generic" image that can be installed
	# on a USB (da0) or on an hard drive (ad0).
	# If FreeBSD 7.2 source code detected, download latest nanobsd.sh script

	if [ "${SRC_VERSION}" = "7.2" ]; then
		if [ ! -f ../nanobsd.bak.7_2 ]; then
			pprint 3 "FreeBSD 7.2 source detected"
			(
			cd ..
			pprint 3 "Backup old nanobsd.sh"
			mv nanobsd.sh nanobsd.bak.7_2
			pprint 3 "Download new nanobsd.sh script"
				if [ ! `fetch -o nanobsd.sh "http://www.freebsd.org/cgi/cvsweb.cgi/~checkout~/src/tools/tools/nanobsd/nanobsd.sh?rev=1.28.2.4"` ]; then
				pprint 3 "Restoring original nanobsd.sh"	
				mv nanobsd.bak.7_2 nanobsd.sh
				pprint 3 "ERROR: Can't download latest nanobsd.sh script"
				exit 1
			fi
			)
		fi
	fi
	pprint 3 "Checking in NanoBSD allready glabel patched"
	grep -q 'GLABEL' ${NANOBSD_DIR}/nanobsd.sh
	if [ $? -eq 0 ]; then
		pprint 3 "NanoBSD allready glabel patched"
	else
		pprint 3 "Patching NanoBSD with glabel support"
		patch ${NANOBSD_DIR}/nanobsd.sh nanobsd.glabel.patch
	fi

	# Adding amd64 support to NanoBSD:
	if [ "$TARGET_ARCH" = "amd64"  ]; then
		pprint 3 "Checking in NanoBSD allready amd64 patched"
		grep -q 'amd64' ${NANOBSD_DIR}/nanobsd.sh
		if [ $? -eq 0 ]; then 
			pprint 3 "NanoBSD allready amd64 patched"
		else
			pprint 3 "Patching NanoBSD with amd64 support"
			patch ${NANOBSD_DIR}/nanobsd.sh nanobsd.amd64.patch
		fi
	fi

	# Adding another cool patch that fix a lot's of problem
	# http://www.freebsd.org/cgi/query-pr.cgi?pr=136889
	pprint 3 "Checking in NanoBSD allready PR-136889 patched"
	grep -q 'NANO_BOOT2CFG' ${NANOBSD_DIR}/nanobsd.sh
	if [ $? -eq 0 ]; then 
		pprint 3 "NanoBSD allready PR-136889 patched"
	else
		pprint 3 "Patching NanoBSD with some fixes (PR-136889)"
		patch ${NANOBSD_DIR}/nanobsd.sh nanobsd.pr-136889.patch
	fi

}

##### Check if previous NanoBSD make stop correctly by unoumt all tmp mount
# exit with 0 if no problem detected
# exit with 1 if problem detected, but clean it
# exit with 2 if problem detected and can't clean it
check_clean() {
	if [ ! `mount | grep -q '<above>'` ]; then 
		pprint 1 "WARNING: Unmounted NanoBSD works directory found!"
		pprint 1 "This can create a bug that delete all your /usr/src directory"
		for d in `mount | grep '<above>' | cut -d ' ' -f 3`
		do
			echo "Try to unmount: $d"
			umount $d
			if [ $? -ne 0 ]; then
      				exit 2 
    			fi

		done
		return 1
	else
		return 0
	fi
}

usage () {
        (
        echo "Usage: $0 -bkwzdh [-c vga|serial] [-a i386|amd64]"
        echo "  -c      specify console type: vga (default) or serial"
        echo "  -a      specify target architecture: i386 or amd64"
		echo "          if not specified, use local system arch (`uname -m`)"
        echo "  -b      suppress buildworld and buildkernel"
		echo "  -k      suppress buildkernel"
		echo "  -w      suppress buildworld"
        echo "  -z      prevent to bzip the full image"
        echo "  -d      Enable debug"
		echo "  -h      Display this help message"
        ) 1>&2
        exit 2
}

#############################################
############ Main code ######################
#############################################

pprint 1 "BSD Router Project image build script"
pprint 1 ""

#Get argument

TARGET_ARCH=`uname -m`
DEBUG=""
SKIP_REBUILD=""
INPUT_CONSOLE="vga"
ZIP_IMAGE="y"
args=`getopt c:a:zbdhkw $*`
if [ $? -ne 0 ] ; then
        usage
        exit 2
fi

set -- $args
DELETE_ALL=true
for i
do
        case "$i"
        in
        -a)
                case "$2" in
				amd64)
					TARGET_ARCH="amd64"
					;;
				i386)
					TARGET_ARCH="i386"
					;;
				esac
				shift
				shift
                ;;
        -c)
                case "$2" in
                vga)
                    INPUT_CONSOLE="vga"
                    ;;
                serial)
                    INPUT_CONSOLE="serial"
                    ;;
                esac
				shift
				shift
                ;;
        -b)
                SKIP_REBUILD="-b"
				DELETE_ALL=false
                shift
                ;;
		-k)
                SKIP_REBUILD="-k"
				DELETE_ALL=false
                shift
                ;;
		-w)
                SKIP_REBUILD="-w"
				DELETE_ALL=false
                shift
                ;;

        -d)
                DEBUG="-x"
                shift
                ;;
		-z)
				ZIP_IMAGE="n"
				shift
				;;
        -h)
                usage
                ;;
        --)
                shift
                break
        esac
done

if [ $# -gt 0 ] ; then
        echo "$0: Extraneous arguments supplied"
        usage
fi

check_current_dir
check_system
check_clean

pprint 1 "Will generate an BSD Router Project image with theses values:"
pprint 1 "- Target architecture: ${TARGET_ARCH}"
pprint 1 "- Console : ${INPUT_CONSOLE}"
if [ "${SKIP_REBUILD}" = "" ]; then
	pprint 1 "- Build the full world (take about 2 hours): YES"
else
	pprint 1 "- Build the full world (take about 2 hours): NO"
fi
if [ "${ZIP_IMAGE}" = "y" ]; then
	pprint 1 "- Zip the final full image: YES"
else
	pprint 1 "- Zip the final full image: NO"
fi

system_patch

# Copy the common nanobsd configuration file to /tmp
cp -v BSDRP.nano /tmp/BSDRP.nano

# And add the customized variable to the nanobsd configuration file
echo "############# Variable section (generated by BSDRP make.sh) ###########" >> /tmp/BSDRP.nano

echo "# The default name for any image we create." >> /tmp/BSDRP.nano
echo "NANO_IMGNAME=\"BSDRP_${BSDRP_VERSION}_full_${TARGET_ARCH}_${INPUT_CONSOLE}.img\"" >> /tmp/BSDRP.nano
echo "# The drive name of the media at runtime" >> /tmp/BSDRP.nano
#echo "NANO_DRIVE=$STORAGE_TYPE" >> /tmp/BSDRP.nano

echo "# Kernel config file to use" >> /tmp/BSDRP.nano

case $TARGET_ARCH in
	"amd64") echo "NANO_KERNEL=BSDRP-AMD64" >> /tmp/BSDRP.nano
		pprint 3 "Copying ${TARGET_ARCH} Kernel configuration file"
		case ${SRC_VERSION} in
		"8.0")
			cp -v BSDRP-AMD64.8_0 /usr/src/sys/amd64/conf/BSDRP-AMD64
			;;
		"7.2")
			cp -v BSDRP-AMD64.7_2 /usr/src/sys/amd64/conf/BSDRP-AMD64
			;;
		esac
		;;
	"i386") echo "NANO_KERNEL=BSDRP-I386" >> /tmp/BSDRP.nano
		pprint 3 "Copying ${TARGET_ARCH} Kernel configuration file"
		case ${SRC_VERSION} in
		"8.0")
			cp -v BSDRP-I386.8_0 /usr/src/sys/i386/conf/BSDRP-I386
			;;
		"7.2")
			cp -v BSDRP-I386.7_2 /usr/src/sys/i386/conf/BSDRP-I386
			;;
		esac
		;;
esac

echo "# Bootloader type"  >> /tmp/BSDRP.nano

case $INPUT_CONSOLE in
	"dual") echo "NANO_BOOTLOADER=\"boot/boot0\"" >> /tmp/BSDRP.nano 
	echo "#Configure dual vga/serial console port" >> /tmp/BSDRP.nano
	echo "customize_cmd bsdrp_console_dual" >> /tmp/BSDRP.nano
;;

	"vga") echo "NANO_BOOTLOADER=\"boot/boot0\"" >> /tmp/BSDRP.nano 
	echo "#Configure vga only console port" >> /tmp/BSDRP.nano
	echo "customize_cmd bsdrp_console_vga" >> /tmp/BSDRP.nano
;;
	"serial") echo "NANO_BOOTLOADER=\"boot/boot0sio\"" >> /tmp/BSDRP.nano
	echo "#Configure serial console port" >> /tmp/BSDRP.nano
	echo "customize_cmd bsdrp_console_serial" >> /tmp/BSDRP.nano
;;
esac

# Export some variables for using them under nanobsd
export TARGET_ARCH

# Delete the destination dir
if ($DELETE_ALL); then
	if [ -d /usr/obj/nanobsd.BSDRP ]; then
		pprint 1 "Delete existing /usr/obj/nanobsd.BSRP directory"
		rm -rf /usr/obj/nanobsd.BSDRP
	fi
fi
# Start nanobsd using the BSDRP configuration file
pprint 1 "Launching NanoBSD build process..."
sh ${DEBUG} ../nanobsd.sh ${SKIP_REBUILD} -c /tmp/BSDRP.nano

# Testing exit code of NanoBSD:
if [ $? -eq 0 ]; then
	pprint 1 "NanoBSD build seems finish successfully."
else
	pprint 1 "ERROR: NanoBSD meet an error, check the log files here:"
	pprint 1 "/usr/obj/nanobsd.BSDRP/"	
	pprint 1 "An error during the build world or kernel can be caused by"
	pprint 1 "a bug in the FreeBSD-current code"	
	pprint 1 "try to re-sync your code" 
	exit 1
fi

# The exit code on NanoBSD doesn't work for port compilation/installation
if [ ! -f /usr/obj/nanobsd.BSDRP/_.disk.image ]; then
	pprint 1 "ERROR: NanoBSD meet an error (port installation/compilation ?)"
	exit 1
fi

BSDRP_FILENAME="BSDRP_${BSDRP_VERSION}_upgrade_${TARGET_ARCH}_${INPUT_CONSOLE}.img"
if [ -f /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2 ]; then
	pprint 1 "Backuping old BSDRP upgrade image..."
	mv -f /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2 /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2.bak
fi 
pprint 1 "Zipping the BSDRP upgrade image..."
mv /usr/obj/nanobsd.BSDRP/_.disk.image /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}
bzip2 -9vf /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}
pprint 1 "You will found the zipped BSDRP upgrade image file here:"
pprint 1 "/usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2"

BSDRP_FILENAME="BSDRP_${BSDRP_VERSION}_full_${TARGET_ARCH}_${INPUT_CONSOLE}.img"
if [ "$ZIP_IMAGE" = "y" ]; then
	if [ -f /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME} ]; then
		pprint 1 "Backuping old BSDRP full zipped image..."
		mv -f /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2 /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2.bak
	fi 
	pprint 1 "Zipping the BSDRP full image..." 
	bzip2 -9vf /usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}
   	pprint 1 "You will found the zipped BSDRP full image file here:"
   	pprint 1 "/usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}.bz2"
else
	pprint 1 "You will found the BSDRP full image file here:"
   	pprint 1 "/usr/obj/nanobsd.BSDRP/${BSDRP_FILENAME}"
fi
pprint 1 "Generating checksum..."
date >> /usr/obj/nanobsd.BSDRP/checksums.txt
md5 /usr/obj/nanobsd.BSDRP/BSDRP_${BSDRP_VERSION}* >> /usr/obj/nanobsd.BSDRP/checksums.txt
sha256 /usr/obj/nanobsd.BSDRP/BSDRP_${BSDRP_VERSION}* >> /usr/obj/nanobsd.BSDRP/checksums.txt
pprint 1 "Done !"
exit 0