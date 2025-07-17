## CCStudio
Check out the [Chinese version 中文简体](https://github.com/zfb132/ccstudio/blob/main/README_zh-CN.md)

### Software Configuration

1. **Supported CCStudio versions**:
   - 10.x (tested versions `10.0.0.00010`, `10.4.0.00006`)
   - 11.x (tested versions `11.0.0.00012`, `11.2.0.00007`)
   - 12.x (tested versions `12.0.0.00009`, `12.8.1.00005`)
   - 20.x (tested version `20.2.0.00012`)
2. **Supported Ubuntu versions**: Ubuntu 20.04 and above (tested `20.04`, `22.04`, `24.04`)
3. **mmWave SDK**: Installation of specific versions of the [mmWave SDK](https://www.ti.com/tool/MMWAVE-SDK) is supported (tested version `03.06.02.00-LTS`).
4. **SYS/BIOS**: [SYS/BIOS](https://software-dl.ti.com/dsps/dsps_public_sw/sdo_sb/targetcontent/bios/sysbios/) is supported (tested version `6.73.01.01`).

[This repository](https://github.com/zfb132/ccstudio) provides Docker images for installing [Code Composer Studio](https://www.ti.com/tool/CCSTUDIO) on Linux systems (headless), making it easy to develop TI projects—especially in CI/CD environments. You can also use the included [configure.sh](https://github.com/zfb132/ccstudio/blob/main/configure.sh) script to install CCStudio on your own Linux machine.

Important directories in the container:  
- `/ccs_projects`: CCStudio project directory (must mount a local directory here, as the `entrypoint.sh` script looks for project files in this directory)
- `/workspaces`: CCStudio workspace directory (the container's CCS workspace directory is `/workspaces`, also used for storing build results)
- `/opt/ti`: Installation directory for TI products (CCStudio, mmWave SDK, SYS/BIOS are installed here)

#### Linux Installation Guides by Version
- [CCS Linux Host Support](https://software-dl.ti.com/ccs/esd/documents/ccs_linux_host_support.html)  
- [CCS Linux Host Support v12](https://software-dl.ti.com/ccs/esd/documents/ccsv12_linux_host_support.html)  
- [CCS Installation Guide v20](https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_installation.html)  

#### Command-Line Interface Documentation
- [CCS Command Line Interface (v12 and below)](https://software-dl.ti.com/ccs/esd/documents/ccs_projects-command-line.html)  
- [CCS Command Line Interface (v20 and above)](https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_project-command-line.html)  

## Building the Docker Images
### Automatic Build
Use `make` to build images:  
```bash
# List available targets
make list

# Build a specific image
make ubuntu24.04-20.2.0.00012-mmw

# Build all images sequentially
make all

# Build all images in parallel (logs will interleave)
make -j $(nproc) all

# Generate docker-compose.yaml for parallel builds
make gen_compose

# Build with docker-compose
docker compose -f docker-compose.yaml --parallel 2 build
```

### Manual Build
Example build script:  
```bash
# Optional build args:
#   --network host
#   --build-arg "HTTP_PROXY=http://127.0.0.1:9900/" \
#   --build-arg "HTTPS_PROXY=http://127.0.0.1:9900/" \
#   --progress=plain --no-cache

# If MMWSDK_COMPONENTS or BIOS_VERSION is empty, the corresponding component is skipped
export UBUNTU_VERSION=24.04
export CCSTUDIO_VERSION=20.2.0.00012
export CCS_COMPONENTS="PF_MMWAVE,PF_C6000SC,PF_TM4C"
export MMWSDK_VERSION="03.06.02.00-LTS"
export MMWSDK_COMPONENTS="ALL"
export BIOS_VERSION="6.73.01.01"
# use major.minor version as CCS version identifier
export CCS_VERSION_SHORT=$(echo ${CCSTUDIO_VERSION} | cut -d '.' -f 1-2)
export tag="whuzfb/ccstudio:${CCS_VERSION_SHORT}-ubuntu${UBUNTU_VERSION}"
docker build -t ${tag} . \
  --build-arg "OS_VERSION=${UBUNTU_VERSION}" \
  --build-arg "CCS_VERSION=${CCSTUDIO_VERSION}" \
  --build-arg "CCS_COMPONENTS=${CCS_COMPONENTS}" \
  --build-arg "MMWSDK_VERSION=${MMWSDK_VERSION}" \
  --build-arg "MMWSDK_COMPONENTS=${MMWSDK_COMPONENTS}" \
  --build-arg "BIOS_VERSION=${BIOS_VERSION}"
```

## Running the Container
Pull the image from Docker Hub:  
```bash
# Pull the latest ccstudio image (20.2-ubuntu24.04-mmw)
docker pull whuzfb/ccstudio:latest
```
Or use your locally built image.

Mount your local project directory to `/ccs_projects` in the container and start the build:  
```bash
# assuming your local project directory is ./mmw_oob
git clone --recursive https://github.com/zfb132/mmw_oob.git ./mmw_oob
# this directory contains out_of_box_6843_isk_mss.projectspec file with Debug configuration
# run the following command to compile the project inside the container
# if you want to save the results, use -v ./results:/workspaces (the container's CCS working directory is /workspaces)
# default timezone is UTC, you can change it by setting -e TZ=... (e.g., -e TZ=Asia/Shanghai)
mkdir ./results
docker run \
  -e TZ=UTC \
  -v ./mmw_oob:/ccs_projects \
  -v ./results:/workspaces \
  -it --rm --name ccstudio whuzfb/ccstudio:latest \
  "out_of_box_6843_isk_mss.projectspec" "Debug"
```

## CCStudio Components
List of installable product families (see CLI installer reference [here](https://software-dl.ti.com/ccs/esd/documents/ccs_installer-cli.html)):  

|  Product family   |                               Description                                    |            OS               |
|      :---:        |                                  :---:                                       |           :---:             |
| PF_MSP430         | MSP430 ultra-low power MCUs                                                  | windows-x64, linux-x64, osx |
| PF_MSP432         | SimpleLink™ MSP432™ low power + performance MCUs                             | windows-x64, linux-x64, osx |
| PF_CC2X           | SimpleLink™ CC13xx and CC26xx Wireless MCUs                                  | windows-x64, linux-x64, osx |
| PF_CC3X           | SimpleLink™ Wi-Fi® CC32xx Wireless MCUs                                      | windows-x64, linux-x64, osx |
| PF_CC2538         | CC2538 IEEE 802.15.4 Wireless MCUs                                           | windows-x64, linux-x64, osx |
| PF_C28            | C2000 real-time MCUs                                                         | windows-x64, linux-x64, osx |
| PF_TM4C           | TM4C12x ARM® Cortex®-M4F core-based MCUs                                     | windows-x64, linux-x64, osx |
| PF_PGA            | PGA Sensor Signal Conditioners                                               | windows-x64, linux-x64, osx |
| PF_HERCULES       | Hercules™ Safety MCUs                                                        | windows-x64, linux-x64, osx |
| PF_SITARA         | Sitara™ AM3x, AM4x, AM5x and AM6x MPUs (will also include AM2x for CCS 10.x) | windows-x64, linux-x64      |
| PF_SITARA_MCU     | Sitara™ AM2x MCUs (only supported in CCS 11.x and greater)                   | windows-x64, linux-x64      |
| PF_OMAPL          | OMAP-L1x DSP + ARM9® Processor                                               | windows-x64, linux-x64      |
| PF_DAVINCI        | DaVinci (DM) Video Processors                                                | windows-x64, linux-x64      |
| PF_OMAP           | OMAP Processors                                                              | windows-x64, linux-x64      |
| PF_TDA_DRA        | TDAx Driver Assistance SoCs & Jacinto DRAx Infotainment SoCs                 | windows-x64, linux-x64      |
| PF_C55            | C55x ultra-low-power DSP                                                     | windows-x64, linux-x64      |
| PF_C6000SC        | C6000 Power-Optimized DSP                                                    | windows-x64, linux-x64      |
| PF_C66AK_KEYSTONE | 66AK2x multicore DSP + ARM® Processors & C66x KeyStone™ multicore DSP        | windows-x64, linux-x64      |
| PF_MMWAVE         | mmWave Sensors                                                               | windows-x64, linux-x64      |
| PF_C64MC          | C64x multicore DSP                                                           | windows-x64, linux-x64      |
| PF_DIGITAL_POWER  | UCD Digital Power Controllers                                                | windows-x64, linux-x64      |


## References

- [uoohyo/ccstudio-ide](https://github.com/uoohyo/docker-ccstudio-ide)  
- [uoohyo/action-ccstudio-ide](https://github.com/uoohyo/action-ccstudio-ide)  
- [ccstudio code composer studio 12.8 and uniflash 8.7 on ubuntu 24.04](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1412767/ccstudio-code-composer-studio-12-8-and-uniflash-8-7-on-ubuntu-24-04)  
- [codecomposer installing ccs 20.2.0 into a docker container](https://e2e.ti.com/support/tools/code-composer-studio-group/ccs/f/code-composer-studio-forum/1532443/codecomposer-installing-ccs-20-2-0-into-a-docker-container)  
