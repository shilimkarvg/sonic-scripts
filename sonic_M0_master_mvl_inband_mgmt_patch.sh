#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation

#
# patch script for ARM32/ARMHF M0 board
#

ver=`docker info --format '{{json .ServerVersion}}'`
if [ ${ver:1:2} -gt 18 ]
then
	echo -e "FATAL: Docker version should be 18.x.y, \nplease execute below commands\n"
	echo "$ sudo apt-get install --allow-downgrades  -y docker-ce=5:18.09.0~3-0~ubuntu-xenial"
	echo "$ sudo apt-get install --allow-downgrades  -y docker-ce-cli=5:18.09.0~3-0~ubuntu-xenial"
	exit
fi


url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"

declare -a PATCHES=(P1 P2 P3 P4 P5)
declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3392 3687 4510 4575 4535 4522 4650" [URL]="$url" [PREREQ]="" [POSTREQ]="")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1162 1281" [URL]="$url" [PREREQ]="" )
declare -A P3=( [NAME]=sonic-mgmt-framework [DIR]=src/sonic-mgmt-framework [PR]="46" [URL]="$url" [PREREQ]="" )
declare -A P4=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="134" [URL]="$url" [PREREQ]="" )
declare -A P5=( [NAME]=sonic-platform-common [DIR]=src/sonic-platform-common [PR]=74 [URL]="$url" [PREREQ]="" )

CWD=`pwd`

#URL_CMD="wget $url/$module/pull/$pr.diff"
for f in ${PATCHES[*]}
do
	P_NAME=${f}[NAME]
	echo "INFO: ${!P_NAME} ... "
	P_DIR=${f}[DIR]
	echo "CMD: cd ${!P_DIR}"
	cd ${!P_DIR}
	P_PRS=${f}[PR]
	P_URL=${f}[URL]
	P_PREREQ=${f}[PREREQ]
	P_POSTREQ=${f}[POSTREQ]

    if [ -n "${!P_PREREQ}" ]
    then
        echo "INFO calling prereq ${!P_PREREQ}"
        eval ${!P_PREREQ}
    fi

	for p in ${!P_PRS}
	do
		echo "INFO: URL ${!P_URL}/${!P_NAME}/pull/${p}.diff"
		rm -f ${p}.diff || true
		wget "${!P_URL}/${!P_NAME}/pull/${p}.diff"
		if [ -f ${p}.diff ]
		then
			echo "INFO: patch -p1 < ${p}.diff"
			patch -p1 -f --dry-run < ${p}.diff
			if [ $? -eq 0 ]; then
				echo "INFO: Applying patch"
				patch -p1 < ${p}.diff
				else
				echo "ERROR: Patch ${!P_NAME} ${p} has failures, try manually"
				fi
			rm -f ${p}.diff
		else
			echo "ERROR: Could not download patch ${!P_NAME} ${p}.diff"
		fi
	done
			
    if [ -n "${!P_POSTREQ}" ]
    then
        echo "INFO calling post script ${!P_POSTREQ}"
        eval ${!P_POSTREQ}
    fi
	cd ${CWD}
done

# Workarounds for Build machine
# Change docker spawn wait time to 4 sec
#cd sonic-buildimage
sed -i 's/sleep 1/sleep 4/g' Makefile.work

# WA to restart networking for inband mgmt
sed -i '/build_version/i \
inband_mgmt(){\
 while :; do\
   ip -br link show eth0 2> /dev/null\
   if [ $? -eq 0 ]; then\
       ip -br address show eth0 | grep -qw "UP" 2>/dev/null\
       if [ $? -ne 0 ]; then\
         ip -br link show eth0 | grep -q "eth0@Eth" 2> /dev/null\
         if [ $? -eq 0 ]; then\
           systemctl restart networking\
           intf=$(ip link show eth0 | grep eth0 | cut -d@ -f2| cut -d: -f1)\
           config interface startup $intf\
         fi\
       fi\
       sleep 120\
   else\
     sleep 10\
   fi\
 done\
}\
inband_mgmt &' files/image_config/platform/rc.local
