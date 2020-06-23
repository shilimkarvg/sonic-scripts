# sonic-scripts

[![Marvell Technologies](https://www.marvell.com/content/dam/marvell/en/rebrand/marvell-logo3.svg)](https://www.marvell.com/)

# Description

Marvell patch script to do git patch/apply all open PRs required to build SONIC image

### M0/DNI-ET6448M Platform
* SONIC Device: 
    * armhf-marvell_et6448m_52x-r0
* ARCH: ARMHF
* CPU: Armada385
* Port: 48x1G+4x10G
```sh
sonic_M0_master_mvl_patch.sh                - Master Jun09 Commit
sonic_M0_master_mvl_inband_mgmt_patch.sh    - Master Apr17 Commint
sonic_M0_mvl_patch.sh                       - 201911 Dec14 Commit
```

### Falcon Platform
* SONIC Device: 
    * x86_64-marvell_db98cx8580_16cd-r0 
    * x86_64-marvell_db98cx8580_32cd-r0
    * arm64-marvell_db98cx8580_16cd-r0 
    * arm64-marvell_db98cx8580_32cd-r0

    ARCH        | CPU
    ------------|--------
    ARM64       | Armada7020
    X86_64      | Xeon

* Port: 12.8T, 6.4T

```sh
sonic_falcon_mvl_patch.sh                   - 201911 Dec14 Commit 
sonic_falcon_201911_mvl_patch.sh            - 201911 May06 Commit
```
