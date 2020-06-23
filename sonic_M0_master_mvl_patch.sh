#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation

set -e

#
# patch script for ARM32/ARMHF M0 board
#

#
# CONFIGURATIONS:-
#

SONIC_MASTER_JUN09_COMMIT="f31eabb5ee65f7d37d57d0da85dacf39d3b5fad1"

declare -a PATCHES=(P1 P2 P3 P4 P5 P6)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"

declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3687 4757" [URL]="$url" [PREREQ]="" [POSTREQ]="")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1280 1325" [URL]="$url" [PREREQ]="" )
declare -A P3=( [NAME]=sonic-swss-common [DIR]=src/sonic-swss-common [PR]="352" [URL]="$url" [PREREQ]="" )
declare -A P4=( [NAME]=sonic-mgmt-framework [DIR]=src/sonic-mgmt-framework [PR]="46" [URL]="$url" [PREREQ]="" )
declare -A P5=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="apply_buster_kernel" )
declare -A P6=( [NAME]=sonic-platform-common [DIR]=src/sonic-platform-common [PR]="" [URL]="$url" [PREREQ]="" )

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`
SCRIPT_DIR=$(dirname $0)

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log ""
    log ""
    log "STEPS TO BUILD:"
    log "git clone https://github.com/Azure/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_MASTER_JUN09_COMMIT"
    log "git checkout -b mrvl"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "make configure PLATFORM=marvell-armhf PLATFORM_ARCH=armhf"
    log "make all"
    log ""
    log ""
}


apply_patches()
{
    CWD=`pwd`
    #URL_CMD="wget $url/$module/pull/$pr.diff"
    for f in ${PATCHES[*]}
    do
        P_NAME=${f}[NAME]
        log "INFO: ${!P_NAME} ... "
        P_DIR=${f}[DIR]
        log "CMD: cd ${!P_DIR}"
        cd ${!P_DIR}
        P_PRS=${f}[PR]
        P_URL=${f}[URL]
        P_PREREQ=${f}[PREREQ]
        P_POSTREQ=${f}[POSTREQ]

        if [ -n "${!P_PREREQ}" ]
        then
            log "INFO calling prereq ${!P_PREREQ}"
            eval ${!P_PREREQ}
        fi

        for p in ${!P_PRS}
        do
            log "INFO: URL ${!P_URL}/${!P_NAME}/pull/${p}.diff"
            rm -f ${p}.diff || true
            wget "${!P_URL}/${!P_NAME}/pull/${p}.diff"
            if [ -f ${p}.diff ]
            then
                log "INFO: patch -p1 < ${p}.diff"
                patch -p1 -f --dry-run < ${p}.diff
                if [ $? -eq 0 ]; then
                    log "INFO: Applying patch"
                    patch -p1 < ${p}.diff
                else
                    log "ERROR: Patch ${!P_NAME} ${p} has failures, try manually"
                fi
                rm -f ${p}.diff
            else
                log "ERROR: Could not download patch ${!P_NAME} ${p}.diff"
            fi
        done

        if [ -n "${!P_POSTREQ}" ]
        then
            log "INFO calling post script ${!P_POSTREQ}"
            eval ${!P_POSTREQ}
        fi
        cd ${CWD}
    done
}

misc_workarounds()
{
    # Workarounds for Build machine
    # Change docker spawn wait time to 4 sec
    #cd sonic-buildimage
    sed -i 's/sleep 1/sleep 4/g' Makefile.work

    # Disable Telemetry
    sed -i 's/ENABLE_MGMT_FRAMEWORK = y/ENABLE_MGMT_FRAMEWORK = N/g' rules/config

    # Add entropy
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
python /etc/ent.py &' files/image_config/platform/rc.local

}

inband_mgmt_fix()
{
    # WA to restart networking for inband mgmt
    sed -i '/build_version/i \
/bin/sh /etc/inband_mgmt' files/image_config/platform/rc.local

    sed -i '/platform rc.local/i \
sudo cp $IMAGE_CONFIGS/platform/inband_mgmt $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2

    rm -f files/image_config/platform/inband_mgmt
    echo "#inband_mgmt" > files/image_config/platform/inband_mgmt
sed -i '$ a \
inband_mgmt(){\
 rmmod i2c-dev \
 rmmod i2c_mux_gpio \
 rmmod i2c_mv64xxx \
 modprobe i2c_mv64xxx \
 modprobe i2c-dev \
 modprobe i2c_mux_gpio \
 sleep 60 \
 while :; do\
   ip -br link show eth0 2> /dev/null\
   if [ $? -eq 0 ]; then\
       ip address show eth0 | grep -qw "inet" 2>/dev/null\
       if [ $? -ne 0 ]; then\
           systemctl restart networking\
       fi\
       sleep 120\
   else\
     sleep 3\
   fi\
 done\
}\
(inband_mgmt > /dev/null)&' files/image_config/platform/inband_mgmt

}

apply_buster_kernel()
{
    git checkout master
    git checkout e2dbd4ced8c32d43844ae1e2066624113a5e0e1d
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_kernel_4.19.67.patch

    patch -p1 --dry-run < ./armhf_kernel_4.19.67.patch
    echo "Patching 4.19.67 armhf"
    patch -p1 < ./armhf_kernel_4.19.67.patch
}

build_kernel_buster()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/armhf_build_kernel_4.19.67_jun09.patch
    patch -p1 --dry-run < ./armhf_build_kernel_4.19.67_jun09.patch
    echo "Patching 4.19.67 build rules"
    patch -p1 < ./armhf_build_kernel_4.19.67_jun09.patch
}

master_armhf_fix()
{

    # sonic slave docker
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_slave_docker.patch
    patch -p1 --dry-run < ./sonic_slave_docker.patch
    echo "SONIC slave build"
    patch -p1 < ./sonic_slave_docker.patch

    # Curl patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/curl_insecure_wa.patch
    patch -p1 --dry-run < ./curl_insecure_wa.patch
    echo "Curl insecure download"
    patch -p1 < ./curl_insecure_wa.patch

    # libyang patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/libyang_wa.patch
    patch -p1 --dry-run < ./libyang_wa.patch
    echo "Libyang fix test"
    patch -p1 < ./libyang_wa.patch

    # sonic_yang patch
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_yang_wa_jun09.patch
    patch -p1 --dry-run < ./sonic_yang_wa_jun09.patch
    echo "sonic-yang fix test"
    patch -p1 < ./sonic_yang_wa_jun09.patch

    # wheel
    sed -i '/keep pip installed/i \
sudo https_proxy=$https_proxy LANG=C chroot $FILESYSTEM_ROOT pip install wheel' build_debian.sh

    # Update SAI 1.6.1
    sed -i 's/1.5.1/1.6.1/g' platform/marvell-armhf/sai.mk

    # Mac address fix
    sed -i  "s/'cat'/'cat '/g" src/sonic-config-engine/sonic_device_util.py

    # Fancontrol
    sed -i '/fancontrol.pid/i \
/bin/cp -f /usr/share/sonic/platform/fancontrol /etc/' dockers/docker-platform-monitor/docker_init.sh

    # snmp subagent
    echo 'sudo sed -i "s/python3.6/python3/g" $FILESYSTEM_ROOT/etc/monit/conf.d/monit_snmp' >> files/build_templates/sonic_debian_extension.j2
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_MASTER_JUN09_COMMIT" ]; then
        log "Checkout sonic-buildimage commit as below to proceed"
        log "git checkout ${SONIC_201911_MAY06_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    misc_workarounds

    inband_mgmt_fix

    build_kernel_buster

    master_armhf_fix
}

main $@
