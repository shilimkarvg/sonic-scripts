#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for ARM arch compilation


#
# patch script for ARM64 Falcon board
#

#
# CONFIGURATIONS:-
#

SONIC_DEC14_COMMIT="1de13ca5fd88f4d0e384a73d2964aea8740296c1"

declare -a PATCHES=(P1 P2 P3 P4)

url="https://github.com/Azure"
urlsai="https://patch-diff.githubusercontent.com/raw/opencomputeproject"


declare -A P1=( [NAME]=sonic-buildimage [DIR]=. [PR]="3687 3734 3955 3963 3941 4016 4043 4066 4081 4168 4205 4280 4293" [URL]="$url" [PREREQ]="" [POSTREQ]="frr_cfg")
declare -A P2=( [NAME]=sonic-swss [DIR]=src/sonic-swss [PR]="1162 1163 1167 1168 1190" [URL]="$url" [PREREQ]="" )
declare -A P3=( [NAME]=sonic-utilities [DIR]=src/sonic-utilities [PR]="811" [URL]="$url" [PREREQ]="util_cfg" [POSTREQ]="installer_patch")
declare -A P4=( [NAME]=sonic-linux-kernel [DIR]=src/sonic-linux-kernel [PR]="125" [URL]="$url" [PREREQ]="prereq_kernel" )

#
# END of CONFIGURATIONS
#

# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

log()
{
    echo $@
    echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

pre_patch_help()
{
    log "STEPS TO BUILD:"
    log "git clone https://github.com/Azure/sonic-buildimage.git"
    log "cd sonic-buildimage"
    log "git checkout $SONIC_DEC14_COMMIT"
    log "make init"

    log "<<Apply patches using patch script>>" 
    log "bash $0"

    log "<<FOR ARM64>> make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64"
    log "<<FOR INTEL>> make configure PLATFORM=marvell"
    log "make all"
}


prereq_kernel()
{
    git fetch --all --tags
    git pull origin master
    git checkout master
    #git checkout 90f7c8480c583734832feee6cc232fe5eeb71422
    git checkout 6650d4eb8d8c1ea4007145e5ffe17c3821298da2
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

installer_patch()
{
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_falcon_dec14_sonic_util.patch
    patch -p1 < mrvl_falcon_dec14_sonic_util.patch
    rm mrvl_falcon_dec14_sonic_util.patch
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
    sed -i 's/ENABLE_SYSTEM_TELEMETRY = y/ENABLE_SYSTEM_TELEMETRY = N/g' rules/config

    #2 TODO: Add Entropy workaround for ARM64
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/ent.py
    mv ent.py files/image_config/platform/ent.py
    sed -i '/platform rc.local/i \
        sudo cp $IMAGE_CONFIGS/platform/ent.py $FILESYSTEM_ROOT/etc/' files/build_templates/sonic_debian_extension.j2
    sed -i '/build_version/i \
        python /etc/ent.py &' files/image_config/platform/rc.local


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
    sed -i 's/"cir":"600",/"cir":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json
    sed -i 's/"cbs":"600",/"cbs":"6000",/g' src/sonic-swss/swssconfig/sample/00-copp.config.json

    # Download hwsku
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/mrvl_sonic_falcon_hwsku.tgz
    rm -fr device/marvell/x86_64-marvell_db98cx8580_32cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8580_32cd-r0  || true
    rm -fr device/marvell/x86_64-marvell_db98cx8540_16cd-r0 || true
    rm -fr device/marvell/arm64-marvell_db98cx8540_16cd-r0  || true
    tar -C device/marvell/ -xzf mrvl_sonic_falcon_hwsku.tgz
    cp -dr device/marvell/arm64-marvell_db98cx8580_32cd-r0 device/marvell/x86_64-marvell_db98cx8580_32cd-r0
    cp -dr device/marvell/arm64-marvell_db98cx8540_16cd-r0 device/marvell/x86_64-marvell_db98cx8540_16cd-r0

    #6 Overwrite default profile with 32x25G 12.8T
    cp -rv device/marvell/x86_64-marvell_db98cx8580_32cd-r0/FALCON32X25G/* device/marvell/x86_64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/
    cp -rv device/marvell/arm64-marvell_db98cx8580_32cd-r0/FALCON32X25G/* device/marvell/arm64-marvell_db98cx8580_32cd-r0/db98cx8580_32cd/

    #7 Overwrite default profile with 16x25G 6.4T
    cp -rv device/marvell/x86_64-marvell_db98cx8540_16cd-r0/FALCON16X25G/* device/marvell/x86_64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/ || true
    cp -rv device/marvell/arm64-marvell_db98cx8540_16cd-r0/FALCON16X25G/* device/marvell/arm64-marvell_db98cx8540_16cd-r0/db98cx8540_16cd/ || true

    #7 ARM64 jessie target
    sed -i 's/apt-get update/apt-get -o Acquire::Check-Valid-Until=false update/'g sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get install -y/apt-get install --force-yes -y/'g sonic-slave-jessie/Dockerfile.j2
    sed -i 's/apt-get -y/apt-get --force-yes -y/'g sonic-slave-jessie/Dockerfile.j2


    #9 TODO: Intel USB access
    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_usb_install_slow.patch
    patch -p1 < sonic_usb_install_slow.patch

}


build_fixes()
{
    sed -i '/RUN apt-get install -y rsyslog/i \
            RUN apt-get install -y cmake \
            RUN apt-mark manual cmake' sonic-slave-stretch/Dockerfile.j2

    sed -i '/EXPOSE 22/i \
            RUN apt-get install -y gem2deb \
            RUN apt-mark manual gem2deb \
            RUN apt-get install -y dh-systemd \
            RUN apt-mark manual dh-systemd \
            RUN apt-get install -y equivs \
            RUN apt-mark manual equivs \
            RUN apt-get install -y javahelper \
            RUN apt-mark manual javahelper \
            RUN apt-get install -y pkg-php-tools \
            RUN apt-mark manual pkg-php-tools \
            RUN apt-get install -y python-stdeb \
            RUN apt-mark manual python-stdeb \
            RUN apt-get install -y libssl1.0-dev \
            RUN apt-mark manual libssl1.0-dev \
            RUN apt-get install -y python-click \
            RUN apt-mark manual python-click \
            RUN apt-get install -y dh-strip-nondeterminism \
            RUN apt-mark manual dh-strip-nondeterminism \
            RUN apt-get install -y debhelper \
            RUN apt-mark manual debhelper \
            RUN apt-get install -y dh-systemd \
            RUN apt-mark manual dh-systemd \
            RUN apt-get install -y kernel-wedge \
            RUN apt-mark manual kernel-wedge \
            RUN apt-get install -y dh-autoreconf \
            RUN apt-mark manual dh-autoreconf \
            RUN apt-get install -y dh-exec \
            RUN apt-mark manual dh-exec \
            RUN apt-get install -y libssl-dev \
            RUN apt-mark manual libssl-dev \
            RUN apt-get install -y dh-make \
            RUN apt-mark manual dh-make' sonic-slave-stretch/Dockerfile.j2

    sed -i 's/dpkg-buildpackage /dpkg-buildpackage -d /' src/isc-dhcp/Makefile

    #sed -i 's/SONIC_/#SONIC_/g' rules/smartmontools.mk
    sed -i 's/dpkg-buildpackage -us/dpkg-buildpackage -d -us/' src/smartmontools/Makefile
    #sed -i 's/dh_installsystemd//' src/smartmontools/smartmontools-6.6/debian/rules
    sed -i '/dpkg-buildpackage/i \
	sed -i "/dh_installsystemd/d" debian/rules' src/smartmontools/Makefile

    sed -i '/fakeroot/i \
ifeq ($(CONFIGURED_ARCH), amd64) \
	echo 11 > debian\/compat \
endif' src/hiredis/Makefile


    sed -i 's/dpkg-buildpackage /dpkg-buildpackage -d /' src/redis/Makefile
    sed -i '/export/i \
ifeq ($(CONFIGURED_ARCH), amd64) \
	echo 11 > debian\/compat \
endif' src/redis/Makefile

    wget -c https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/master/files/sonic_falcon_libteam_dec14.patch
    patch -p1 < sonic_falcon_libteam_dec14.patch
}

main()
{
    sonic_buildimage_commit=`git rev-parse HEAD`
    if [ "$CUR_DIR" != "sonic-buildimage" ]; then
        log "ERROR: Need to be at sonic-builimage git clone path"
        pre_patch_help
        exit
    fi

    if [ "${sonic_buildimage_commit}" != "$SONIC_DEC14_COMMIT" ]; then
        log "Checkout Dec14 sonic-buildimage commit to proceed"
        log "git checkout ${SONIC_DEC14_COMMIT}"
        pre_patch_help
        exit
    fi

    date > ${FULL_PATH}/${LOG_FILE}

    apply_patches 

    build_fixes

    misc_workarounds
}

main $@

