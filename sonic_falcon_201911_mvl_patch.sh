#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation

set -e

#
# patch script for ARM64 Falcon board
#

#
# CONFIGURATIONS:-
#

SONIC_201911_MAY06_COMMIT="5e17126ffe42b9c03140d4131e7ae6c41fa2b02d"

declare -a PATCHES=(P1 P2 P3 P4 P5 P6)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"


#declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3687 3734 3955 3963 3941 4016 4043 4066 4081 4168 4205 4280 4293 4535" [URL]="$url" [PREREQ]="" [POSTREQ]="")
declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3734 3955 3963 3941 4043 4168 4205 4280 4293 4535 4575" [URL]="$url" [PREREQ]="" [POSTREQ]="partial_pr_wa")
#declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1162 1163 1167 1168 1190" [URL]="$url" [PREREQ]="swss_workaround" )
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1162 1163 1167 " [URL]="$url" [PREREQ]="swss_workaround" )
declare -A P3=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]="" [URL]="$url" [PREREQ]="util_cfg" )
declare -A P4=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="" [URL]="$url" [PREREQ]="prereq_kernel" )
declare -A P5=( [NAME]=sonic-mgmt-framework [DIR]=src/sonic-mgmt-framework [PR]="46" [URL]="$url" [PREREQ]="" )
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
    log "git checkout $SONIC_201911_MAY06_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
    log ""
    log ""
}

partial_pr_wa()
{
    sed -i 's/amd64/$(CONFIGURED_ARCH)/g' rules/sonic-mgmt-framework.mk
    sed -i 's/amd64/$(CONFIGURED_ARCH)/g' rules/iptables.mk
    sed -i 's/amd64/$(CONFIGURED_ARCH)/g' src/iptables/Makefile
}

prereq_kernel()
{
    #git fetch --all --tags
    #git pull origin master
    #git checkout master
    #git checkout 90f7c8480c583734832feee6cc232fe5eeb71422
    #git checkout 6650d4eb8d8c1ea4007145e5ffe17c3821298da2
    #git revert --no-edit 66e9dfa591369782eff63f1de09818df3a941b29

    wget -c https://github.com/Azure/sonic-linux-kernel/pull/118.diff
    wget -c https://github.com/Azure/sonic-linux-kernel/pull/124.diff
    #sed -i '/net-psample-fix-skb-over-panic.patch/d' 124.diff
    sed -i '/net-psample-fix-skb-over-panic.patch/d' patch/series

    echo "Pacth 118"
    patch -p1 --dry-run < ./118.diff
    patch -p1  < ./118.diff
    sed -i '114i net-psample-fix-skb-over-panic.patch' patch/series
    echo "Pacth 125"
    patch -p1 --dry-run < ./124.diff
    patch -p1  < ./124.diff
}

util_cfg()
{
    git fetch --all --tags
    #git pull origin master
    git checkout master
    git checkout 9a9495579870943c96ce865dacbd23df53643666
}

frr_cfg()
{
    wget https://patch-diff.githubusercontent.com/raw/Azure/sonic-buildimage/pull/4066.diff
    patch -p1 --dry-run < 4066.diff
    patch -p1 < 4066.diff
    rm 4066.diff
}

swss_workaround()
{
    # PR 1190 fails, alternative.
    sed -i 's/platform == MLNX_PLATFORM_SUBSTRING/platform == MRVL_PLATFORM_SUBSTRING/g' orchagent/aclorch.cpp
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

create_temp_rclocal_patch()
{
cat <<EOF > /tmp/rclocal_fix
echo "Marvell: Executing Workarounds !!!!"
python /etc/ent.py

echo "Switch Mac Address Update"
MAC_ADDR=\`ip link show eth0 | grep ether | awk '{print $2}'\`
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8580_16cd-r0/db98cx8580_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/arm64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8580_16cd-r0/db98cx8580_16cd/profile.ini
sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g" /usr/share/sonic/device/x86_64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/profile.ini
find /usr/share/sonic/device/*db98cx* -name profile.ini | xargs sed -i "s/switchMacAddress=.*/switchMacAddress=\$MAC_ADDR/g"
echo "Switch ARP entry threshold"
sysctl -w net.ipv4.neigh.default.gc_thresh1=32000
sysctl -w net.ipv4.neigh.default.gc_thresh2=48000
sysctl -w net.ipv4.neigh.default.gc_thresh3=56000
sysctl -w net.ipv6.neigh.default.gc_thresh1=8000
sysctl -w net.ipv6.neigh.default.gc_thresh2=16000
sysctl -w net.ipv6.neigh.default.gc_thresh3=32000
EOF

}

misc_workarounds()
{
    #1 Disable Telemetry
    if [[ "$FULL_PATH" == *ARM64* ]]; then
        sed -i 's/ENABLE_SYSTEM_TELEMETRY = y/ENABLE_SYSTEM_TELEMETRY = N/g' rules/config
        sed -i 's/ENABLE_MGMT_FRAMEWORK = y/ENABLE_MGMT_FRAMEWORK = N/g' rules/config
    fi
    sed -i 's/RUN apt-get -y build-dep linux/{% if CONFIGURED_ARCH != "arm64" %}\nRUN apt-get -y build-dep linux\n{%- endif %}/g' sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get install -y /apt-get install -y --force-yes /g' sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get -y /apt-get -y --force-yes /g' sonic-slave-jessie/Dockerfile.j2

    #2 Add Entropy workaround for ARM64
    cp ${SCRIPT_DIR}/files/ent.py files/image_config/platform/
    echo 'sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' >> files/build_templates/sonic_debian_extension.j2

    #3 Add ipv4/ipv6 arp gc_thresh
    create_temp_rclocal_patch
    sed '16r /tmp/rclocal_fix' < files/image_config/platform/rc.local > files/image_config/platform/rc.local_new
    mv files/image_config/platform/rc.local files/image_config/platform/rc.local_orig
    mv files/image_config/platform/rc.local_new files/image_config/platform/rc.local

    #4 Watchdog/select Timeout  workaround
    sed -i 's/(60\*1000)/(500\*1000)/g' src/sonic-sairedis/lib/inc/sai_redis.h
    sed -i 's/TimerWatchdog twd(30 \* 1000000);/TimerWatchdog twd(2147 * 1000000);/g' src/sonic-sairedis/syncd/syncd.cpp
    sed -i 's/#define SELECT_TIMEOUT 1000/#define SELECT_TIMEOUT 1999999/g' src/sonic-swss/orchagent/orchdaemon.cpp

    #5 copp configuration for jumbo
    # Not needed in Master
    #sed -i 's/"cir":"600",/"cir":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json
    #sed -i 's/"cbs":"600",/"cbs":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json

    #6 Copy hwsku files from xps repo 
    if [ -d ${SCRIPT_DIR}/../sai_cpss/sonic/ ]
    then
    rm -fr device/marvell/arm64-marvell_db98cx8580_32cd-r0 || true
    cp -dr ${SCRIPT_DIR}/../sai_cpss/sonic/arm64-marvell_db98cx8580_32cd-r0 device/marvell/arm64-marvell_db98cx8580_32cd-r0
    rm -fr device/marvell/x86_64-marvell_db98cx8580_32cd-r0 || true
    cp -dr ${SCRIPT_DIR}/../sai_cpss/sonic/arm64-marvell_db98cx8580_32cd-r0 device/marvell/x86_64-marvell_db98cx8580_32cd-r0
    rm -fr device/marvell/arm64-marvell_db98cx8540_16cd-r0 || true
    cp -dr ${SCRIPT_DIR}/../sai_cpss/sonic/arm64-marvell_db98cx8540_16cd-r0 device/marvell/arm64-marvell_db98cx8540_16cd-r0
    rm -fr device/marvell/x86_64-marvell_db98cx8540_16cd-r0 || true
    cp -dr ${SCRIPT_DIR}/../sai_cpss/sonic/arm64-marvell_db98cx8540_16cd-r0 device/marvell/x86_64-marvell_db98cx8540_16cd-r0
    fi

    #7 ARM64 jessie target
    sed -i 's/apt-get update/apt-get -o Acquire::Check-Valid-Until=false update/g' sonic-slave-jessie/Dockerfile.j2

    #8 TODO: Docker version
    sed -i 's/DOCKER_VERSION=18.06.3~ce~3-0~debian/DOCKER_VERSION=5:19.03.6~3-0~debian-stretch/g' build_debian.sh

    #9 Kenrel version change
    sed -i 's/4.9.0-9-2/4.9.0-11-2/g' platform/marvell-arm64/sonic_fit.its
    sed -i 's/4.9.0-9-2/4.9.0-11-2/g' platform/marvell-arm64/platform.conf

    #9 TODO: Intel USB access
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_usb_install_slow.patch
    patch -p1 < sonic_usb_install_slow.patch

    # LAST -- remove dirty from Image version
    # git add -u && git commit -m "Committing Marvell Workarounds" || echo "Code is clean, no commit required"
}

sonicbuild_prereq()
{
    #1 Add user permission to docker
    U=`whoami`
    sudo setfacl -m user:${U}:rw /var/run/docker.sock
    sudo usermod -aG sudo ${U}
    sudo usermod -aG docker ${U}

    #2 Install j2
    sudo apt-get install -y python-pip
    sudo pip install --force-reinstall --upgrade jinja2>=2.10
    sudo pip install j2cli
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_201911_MAY06_COMMIT" ]; then
        log "Checkout sonic-buildimage commit as below to proceed"
        log "git checkout ${SONIC_201911_MAY06_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    misc_workarounds

    sonicbuild_prereq
}

main $@

