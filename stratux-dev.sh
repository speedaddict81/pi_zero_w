# Copyright (c) 2016 Joseph D Poirier
# Distributable under the terms of The New BSD License
# that can be found in the LICENSE file.


BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)


if [ $(whoami) != 'root' ]; then
    echo "${BOLD}${RED}This script must be executed as root, exiting...${WHITE}${NORMAL}"
    exit
fi


SCRIPTDIR="`pwd`"

#set -e

#outfile=setuplog
#rm -f $outfile

#exec > >(cat >> $outfile)
#exec 2> >(cat >> $outfile)

#### stdout and stderr to log file
#exec > >(tee -a $outfile >&1)
#exec 2> >(tee -a $outfile >&2)

#### execute the script: bash stratux-dev.sh

#### Revision numbers found via cat /proc/cpuinfo
# [Labeled Section]                                       [File]
# Hardware check                                        - stratux-dev.sh
# Boot config settings                                  - rpi.sh
#
RPI0xREV=900092
RPI0yREV=900093

RPI2BxREV=a01041
RPI2ByREV=a21041

RPI3BxREV=a02082
RPI3ByREV=a22082
RPIZEROW=9000c1
ODROIDC2=020b

CHIP=0000

#### unchecked
RPIBPxREV=0010
RPIAPxREV=0012
RPIBPyREV=0013

REVISION="$(cat /proc/cpuinfo | grep Revision | cut -d ':' -f 2 | xargs)"


# Processor 
# [Labeled Section]                                       [File]
# Go bootstrap compiler installation                    - stratux-setup.sh
#
ARM6L=armv6l
ARM7L=armv7l
ARM64=aarch64

MACHINE="$(uname -m)"

# Edimax WiFi dongle
EW7811Un=$(lsusb | grep EW-7811Un)


echo "${MAGENTA}"
echo "************************************"
echo "**** Stratux Setup Starting... *****"
echo "************************************"
echo "${WHITE}"

if which ntp >/dev/null; then
    ntp -q -g
fi


##############################################################
##  Stop exisiting services
##############################################################
echo
echo "${YELLOW}**** Stop exisiting services... *****${WHITE}"

service stratux stop
echo "${MAGENTA}stratux service stopped...${WHITE}"

if [ -f "/etc/init.d/stratux" ]; then
    # remove old file
    rm -f /etc/init.d/stratux
    echo "/etc/init.d/stratux file found and deleted...${WHITE}"
fi

if [ -f "/etc/init.d/hostapd" ]; then
    service hostapd stop
    echo "${MAGENTA}hostapd service found and stopped...${WHITE}"
fi

if [ -f "/etc/init.d/isc-dhcp-server" ]; then
    service isc-dhcp-server stop
    echo "${MAGENTA}isc-dhcp service found and stopped...${WHITE}"
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  Hardware check
##############################################################
echo
echo "${YELLOW}**** Hardware check... *****${WHITE}"

if [ "$REVISION" == "$RPI2BxREV" ] || [ "$REVISION" == "$RPI2ByREV" ]  || [ "$REVISION" == "$RPI3BxREV" ] || [ "$REVISION" == "$RPI3ByREV" ] || [ "$REVISION" == "$RPI0xREV" ] || [ "$REVISION" == "$RPI0yREV" ] || [ "$REVISION" == "$RPIZEROW" ]; then
    echo
    echo "${MAGENTA}Raspberry Pi detected...${WHITE}"

    . ${SCRIPTDIR}/rpi.sh
elif [ "$REVISION" == "$ODROIDC2" ]; then
    echo
    echo "${MAGENTA}Odroid-C2 detected...${WHITE}"

    . ${SCRIPTDIR}/odroid.sh
elif [ "$REVISION" == "$CHIP" ]; then
    echo
    echo "${MAGENTA}CHIP detected...${WHITE}"

    . ${SCRIPTDIR}/chip.sh
else
    echo
    echo "${BOLD}${RED}WARNING - unable to identify the board using /proc/cpuinfo...${WHITE}${NORMAL}"

    #exit
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  Go environment setup
##############################################################
echo
echo "${YELLOW}**** Go environment setup... *****${WHITE}"

# if any of the following environment variables are set in .bashrc delete them
if grep -q "export GOROOT_BOOTSTRAP=" "/root/.bashrc"; then
    line=$(grep -n 'GOROOT_BOOTSTRAP=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export GOPATH=" "/root/.bashrc"; then
    line=$(grep -n 'GOPATH=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export GOROOT=" "/root/.bashrc"; then
    line=$(grep -n 'GOROOT=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export PATH=" "/root/.bashrc"; then
    line=$(grep -n 'PATH=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

# only add new paths
XPATH="\$PATH"
if [[ ! "$PATH" =~ "/root/go/bin" ]]; then
    XPATH+=:/root/go/bin
fi

if [[ ! "$PATH" =~ "/root/go_path/bin" ]]; then
    XPATH+=:/root/go_path/bin
fi

echo export GOROOT_BOOTSTRAP=/root/gobootstrap >>/root/.bashrc
echo export GOPATH=/usr/lib/go/ >>/root/.bashrc
echo export GOROOT=/usr/lib/go-1.7/ >>/root/.bashrc
echo export PATH=${XPATH} >>/root/.bashrc

export GOROOT_BOOTSTRAP=/root/gobootstrap
export GOPATH=/usr/lib/go/
export GOROOT=/usr/lib/go-1.7/
export PATH=${PATH}:/usr/bin/
source /root/.bashrc

echo "${GREEN}...done${WHITE}"


##############################################################
##  Stratux build and installation
##############################################################
echo
echo "${YELLOW}**** Stratux build and installation... *****${WHITE}"

cd /root

cd stratux
export CGO_LDFLAGS=-L/usr/local/lib
make all
make install

#### minimal sanity checks
if [ ! -f "/usr/bin/gen_gdl90" ]; then
    echo "${BOLD}${RED}ERROR - gen_gdl90 file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

if [ ! -f "/usr/bin/dump1090" ]; then
    echo "${BOLD}${RED}ERROR - dump1090 file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

echo "${GREEN}...done${WHITE}"


#############################################################
## Copying rc.local file
##############################################################
#echo
#echo "${YELLOW}**** Copying rc.local file... *****${WHITE}"

#chmod 755 ${SCRIPTDIR}/files/rc.local
#cp ${SCRIPTDIR}/files/rc.local /usr/bin/rc.local

#echo "${GREEN}...done${WHITE}"


##############################################################
## Epilogue
##############################################################
echo
echo
echo "${MAGENTA}**** Setup complete, don't forget to reboot! *****${WHITE}"
echo

echo ${NORMAL}
