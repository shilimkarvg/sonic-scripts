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
declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3392 3687 3734 4081 3955 3963 4016 3941 4066" [URL]="$url" [PREREQ]="" [POSTREQ]="frr_cfg")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1162 1168" [URL]="$url" [PREREQ]="" )
declare -A P3=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]="" [URL]="$url" [PREREQ]="util_cfg" )
declare -A P4=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="prereq_kernel" )
declare -A P5=( [NAME]=sonic-platform-common [DIR]=src/sonic-platform-common [PR]=74 [URL]="$url" [PREREQ]="" )

prereq_kernel()
{
    git fetch --all --tags
    git pull origin master
    git checkout master
    git checkout 90f7c8480c583734832feee6cc232fe5eeb71422
    git revert --no-edit 66e9dfa591369782eff63f1de09818df3a941b29
}
util_cfg()
{
    git fetch --all --tags
    git pull origin master
    git checkout master
    git checkout db58367dedd88c2f7c0b8e397ecb1e08548662fa

}
frr_cfg()
{
    wget https://patch-diff.githubusercontent.com/raw/Azure/sonic-buildimage/pull/4066.diff
    patch -p1 < 4066.diff
    rm 4066.diff
}
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
