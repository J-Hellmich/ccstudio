## CCStudio
Check out the [Chinese version 中文简体](https://github.com/zfb132/ccstudio/blob/main/README_zh-CN.md)  

Docker images are available on:  
* [Dockerhub: whuzfb/ccstudio](https://hub.docker.com/r/whuzfb/ccstudio)
* [GHCR: zfb132/ccstudio](https://github.com/zfb132/ccstudio/pkgs/container/ccstudio)

Github Actions workflow: [zfb132/build-ccstudio-project](https://github.com/marketplace/actions/build-ccstudio-project)  
Repository for testing: [zfb132/mmw_oob](https://github.com/zfb132/mmw_oob)

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

Linux installation guides by version
- [CCS Linux Host Support](https://software-dl.ti.com/ccs/esd/documents/ccs_linux_host_support.html)  
- [CCS Linux Host Support v12](https://software-dl.ti.com/ccs/esd/documents/ccsv12_linux_host_support.html)  
- [CCS Installation Guide v20](https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_installation.html)  

Command-line interface documentation
- [CCS Command Line Interface (v12 and below)](https://software-dl.ti.com/ccs/esd/documents/ccs_projects-command-line.html)  
- [CCS Command Line Interface (v20 and above)](https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_project-command-line.html)  

## Running the GUI via X11
To launch the CCS IDE GUI from inside the container while keeping your host clean, use X11 forwarding:

```bash
# Allow local docker access to your X server (temporary)
xhost +local:docker

# Run the helper script (build or pull the image first)
scripts/run_x11.sh whuzfb/ccstudio:latest "$HOME/ccs-workspace"

# CCS will start in the container and use /workspaces as the workspace.
# On exit, the script revokes X access.
```

Notes:
- Requires an X server on the host and `xhost` utility (`sudo apt install x11-xserver-utils`).
- You can mount a local `./ccs_projects` folder; the script auto-binds it to `/ccs_projects` for optional CLI builds.
- For Wayland-only environments, ensure Xwayland is available or consider adding a VNC-based desktop layer.

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

### Using a Local CCS Installer
If you already downloaded the CCS installer (e.g., `CCS12.8.1.00005_linux-x64.tar.gz`), place it in `assets/`. The build copies files from `assets/` to `/ccs_install` in the image, and `configure.sh` will use the local file and skip downloading.

```bash
mkdir -p assets
cp ~/Downloads/CCS12.8.1.00005_linux-x64.tar.gz assets/
make 12.8-ubuntu24.04
```

### GUI-Ready Image (X11)
If you want a GUI-ready image, enable GUI dependencies:

```bash
# Build standard image with GUI deps enabled
GUI_DEPS=1 make 12.8-ubuntu24.04

# Or build a dedicated GUI-tagged image
make 12.8-ubuntu24.04-gui

# Launch via helper
xhost +local:docker
make run-x11-gui

# Pass custom directories via environment (optional)
#   WORKSPACE_DIR: host path for CCS workspace (default $HOME/ccs-workspace)
#   PROJECTS_DIR: host path to mount as /ccs_projects (optional)
# Example:
# WORKSPACE_DIR="$HOME/dev/ccs-workspace" PROJECTS_DIR="$HOME/dev/ccs-projects" make run-x11-gui
```

### Plain Docker Commands (no make)
If you prefer not to use `make`, here are the equivalent steps and commands that the helper script runs to start the CCS GUI via X11. Adjust the image tag and workspace path as needed.

```bash
# 1) Allow local docker to access your X server for this session
xhost +local:docker

# 2) Ensure a workspace directory exists on the host
WORKSPACE_DIR="$HOME/ccs-workspace"
mkdir -p "$WORKSPACE_DIR"

# 3) Run the GUI-enabled image with X11 bindings
#    Use the GUI image built by `make 12.8-ubuntu24.04-gui`
IMAGE_TAG="ccstudio:12.8-ubuntu24.04-gui"

docker run --rm -it \
  --name ccs-x11 \
  -e DISPLAY="$DISPLAY" \
  -e QT_X11_NO_MITSHM=1 \
  -e TZ="${TZ:-Etc/UTC}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v "$WORKSPACE_DIR":/workspaces \
  -v "$CCS_PROJECTS_DIR":/ccs_projects \
  --entrypoint "" \
  "$IMAGE_TAG" bash -lc \
  "/opt/ti/ccs/eclipse/ccstudio -data /workspaces"

# Optional: mount local projects if present
# If you have a ./ccs_projects folder, add:
#   -v "$(pwd)/ccs_projects:/ccs_projects" \

# 4) After CCS exits, you can revoke X access (optional best-effort)
xhost -local:docker
```

### Enter the Running Container
To open a shell inside the running CCS container:

```bash
# Enter the default X11-run container
scripts/enter_container.sh

# Or specify a different container name
scripts/enter_container.sh ccstudio
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


## Prebuilt Docker Images
The build configurations for prebuilt Docker images are defined in the following table:  

|       Docker Tag       | Ubuntu Version |   CCS Version     | CCS Components | mmWave SDK Version | mmWave SDK Components | SYS/BIOS Version |
|         :---:          |      :---:     |       :---:       |      :---:     |       :---:        |         :---:         |      :---:       |
| `20.2-ubuntu24.04-mmw` | `24.04`        | `20.2.0.00012`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `20.2-ubuntu24.04`     | `24.04`        | `20.2.0.00012`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `20.2-ubuntu22.04-mmw` | `22.04`        | `20.2.0.00012`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `20.2-ubuntu22.04`     | `22.04`        | `20.2.0.00012`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `20.2-ubuntu20.04-mmw` | `20.04`        | `20.2.0.00012`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `20.2-ubuntu20.04`     | `20.04`        | `20.2.0.00012`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu24.04-mmw` | `24.04`        | `12.8.1.00005`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu24.04`     | `24.04`        | `12.8.1.00005`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu22.04-mmw` | `22.04`        | `12.8.1.00005`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu22.04`     | `22.04`        | `12.8.1.00005`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu20.04-mmw` | `20.04`        | `12.8.1.00005`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `12.8-ubuntu20.04`     | `20.04`        | `12.8.1.00005`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu24.04-mmw` | `24.04`        | `11.2.0.00007`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu24.04`     | `24.04`        | `11.2.0.00007`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu22.04-mmw` | `22.04`        | `11.2.0.00007`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu22.04`     | `22.04`        | `11.2.0.00007`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu20.04-mmw` | `20.04`        | `11.2.0.00007`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `11.2-ubuntu20.04`     | `20.04`        | `11.2.0.00007`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu24.04-mmw` | `24.04`        | `10.4.0.00006`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu24.04`     | `24.04`        | `10.4.0.00006`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu22.04-mmw` | `22.04`        | `10.4.0.00006`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu22.04`     | `22.04`        | `10.4.0.00006`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu20.04-mmw` | `20.04`        | `10.4.0.00006`    | `PF_ALL`       | `03.06.02.00-LTS`  | `ALL`                 | `""` (skip)      |
| `10.4-ubuntu20.04`     | `20.04`        | `10.4.0.00006`    | `PF_ALL`       | `""` (skip)        | `ALL`                 | `""` (skip)      |

## References

- [uoohyo/ccstudio-ide](https://github.com/uoohyo/docker-ccstudio-ide)  
- [uoohyo/action-ccstudio-ide](https://github.com/uoohyo/action-ccstudio-ide)  
- [ccstudio code composer studio 12.8 and uniflash 8.7 on ubuntu 24.04](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1412767/ccstudio-code-composer-studio-12-8-and-uniflash-8-7-on-ubuntu-24-04)  
- [codecomposer installing ccs 20.2.0 into a docker container](https://e2e.ti.com/support/tools/code-composer-studio-group/ccs/f/code-composer-studio-forum/1532443/codecomposer-installing-ccs-20-2-0-into-a-docker-container)  
