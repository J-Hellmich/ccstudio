ARG OS_VERSION=24.04
FROM ubuntu:${OS_VERSION}
LABEL org.opencontainers.image.authors="Fubin Zhang <zfb132@gmail.com>" \
      org.opencontainers.image.source="https://github.com/zfb132/ccstudio" \
      org.opencontainers.image.url="https://github.com/zfb132/ccstudio" \
      org.opencontainers.image.description="CCStudio Docker Image"

# CCStudio version
ARG CCS_VERSION="20.2.0.00012"
# components to install (comma-separated, use PF_ALL for all)
ARG CCS_COMPONENTS="PF_ALL"
# mmWave SDK version (empty to skip)
ARG MMWSDK_VERSION="03.06.02.00-LTS"
# mmWave SDK components (comma-separated, use ALL for all, empty to skip)
ARG MMWSDK_COMPONENTS="ALL"
# SYS/BIOS version (empty to skip, note: already included in mmWave SDK)
# e.g. 6.73.01.01
ARG BIOS_VERSION=""
# install GUI dependencies (set to 1 to enable)
ARG GUI_DEPS="0"
ARG DEBIAN_FRONTEND=noninteractive

# default installation paths for TI tools (CCStudio, MMWave SDK, SYS/BIOS)
ENV CCS_DIR="/opt/ti"
# default workspace directory for CCStudio in container
ENV WORKSPACE_DIR="/workspaces"
# default language and timezone
# timezone can be changed when running the container with -e TZ=...
ENV LANG=en_US.UTF-8 TZ=UTC
ENV GUI_DEPS=${GUI_DEPS}

COPY configure.sh entrypoint.sh /
# If a local CCS installer is provided, place it where configure.sh looks
# (e.g., assets/CCS12.8.1.00005_linux-x64.tar.gz)
COPY assets/ /ccs_install/

# use only one RUN command to reduce image layers
RUN chmod +x /*.sh && \
    /configure.sh install_base && \
    /configure.sh install_gui_deps && \
    /configure.sh install_ccs && \
    /configure.sh install_mmwave_sdk && \
    /configure.sh install_sys_bios && \
    /configure.sh init_ccs && /configure.sh clean

WORKDIR ${WORKSPACE_DIR}
ENV PATH="${CCS_DIR}/ccs/eclipse/:${PATH}"

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
