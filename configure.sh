#!/bin/bash
set -e

# CCS version
CCS_VERSION="${CCS_VERSION:-20.0.0.00012}"
# CCS installation directory
CCS_DIR="${CCS_DIR:-/opt/ti}"
# CCS workspace directory
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspaces}"
# temporary directory
TMP_DIR="/ccs_install"

# CCS download URL: https://www.ti.com/tool/CCSTUDIO
CCS_URL="https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-J1VdearkvK"
# SYS/BIOS download URL: https://software-dl.ti.com/dsps/dsps_public_sw/sdo_sb/targetcontent/bios/sysbios/
SYS_BIOS_URL="https://software-dl.ti.com/dsps/dsps_public_sw/sdo_sb/targetcontent/bios/sysbios"
# MMWAVE SDK download URL: https://www.ti.com/tool/download/MMWAVE-SDK
MMWAVE_SDK_URL="https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-PIrUeCYr3X"

MAJOR_VER=$(echo "${CCS_VERSION}" | cut -d'.' -f1)
MINOR_VER=$(echo "${CCS_VERSION}" | cut -d'.' -f2)
PATCH_VER=$(echo "${CCS_VERSION}" | cut -d'.' -f3)
BUILD_VER=$(echo "${CCS_VERSION}" | cut -d'.' -f4)

# https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_installation.html#system-check
# libpython3.9.so.1.0 is only required when working with mmWave radar sensor devices
# libc6-i386 is only required when trying to install additional older compilers that use a 32-bit installer
# libtinfo is required by the TI Arm Clang Compiler
install_base() {
    # check Ubuntu major version number
    local UBUNTU_MAJOR
    # UBUNTU_MAJOR=$(lsb_release -rs | cut -d. -f1)
    if [ -f /etc/os-release ]; then
        UBUNTU_MAJOR=$(grep '^VERSION_ID=' /etc/os-release | sed 's/[^0-9]*\([0-9][0-9]*\).*/\1/')
        UBUNTU_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2)
        if [ -z "${UBUNTU_CODENAME}" ]; then
            UBUNTU_CODENAME=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d'=' -f2)
        fi
    elif [ -f /etc/lsb-release ]; then
        UBUNTU_CODENAME=$(grep '^DISTRIB_CODENAME=' /etc/lsb-release | cut -d'=' -f2)
        UBUNTU_MAJOR=$(grep '^DISTRIB_RELEASE=' /etc/lsb-release | cut -d'=' -f2 | cut -d. -f1)
    elif [ -f /etc/issue ]; then
        UBUNTU_MAJOR=$(head -1 /etc/issue | grep -oE '[0-9]+' | head -1)
    else
        echo "Unable to determine Ubuntu codename or version."
        exit 1
    fi
    echo "Detected Ubuntu version: ${UBUNTU_MAJOR}, codename: ${UBUNTU_CODENAME}"
    # if UBUNTU_MAJOR is less than 20, throw an error
    if [ "${UBUNTU_MAJOR}" -lt 20 ]; then
        echo "Error: This script requires Ubuntu 20.04 or later."
        exit 1
    fi

    # default dependency packages
    local COMMON_PKGS="ca-certificates libc6-i386 libusb-0.1-4 libgconf-2-4 libncurses5 libtinfo5"
    local PKGS="${COMMON_PKGS}"

    # ubuntu 24.04: libtinfo5 needs manual download
    local NEED_MANUAL_INSTALL=0

    if [ "${UBUNTU_MAJOR}" -ge 24 ]; then
        # ubuntu 24.04 and above come with libtinfo6 but not libtinfo5, need manual download
        if ! apt-cache show libtinfo5 2>/dev/null | grep -q 'Package:'; then
            PKGS=$(echo "${COMMON_PKGS}" | sed 's/libtinfo5//g' | sed 's/libgconf-2-4//g' | sed 's/libncurses5/libncurses6/g')
            NEED_MANUAL_INSTALL=1
        fi
    fi

    # add i386 architecture support (required by CCS)
    dpkg --add-architecture i386

    apt-get update
    apt-get install --no-install-recommends -y ${PKGS} build-essential unzip wget gnupg curl git
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone
    # add-apt-repository ppa:deadsnakes/ppa -y
    # add deadsnakes PPA
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu ${UBUNTU_CODENAME} main" | tee /etc/apt/sources.list.d/deadsnakes-ppa.list
    # import PPA public key
    # apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg
    apt-get update
    local deb_url="http://mirrors.edge.kernel.org/ubuntu/pool/universe"
    # cCS version below 20 requires Python 2.7
    if [ "${MAJOR_VER}" -lt 20 ]; then
        if [ "${UBUNTU_MAJOR}" -le 22 ]; then
            apt-get install --no-install-recommends -y libpython2.7
        else
            # ubuntu 24.04 and above for CCS versions below 20
            echo "Warning: CCS version ${CCS_VERSION} is not officially supported on Ubuntu ${UBUNTU_MAJOR}."
            apt-get install --no-install-recommends -y libnsl2
            wget -O /tmp/libpython2.7.deb "${deb_url}/p/python2.7/libpython2.7_2.7.18-13ubuntu1.5_amd64.deb"
            wget -O /tmp/libpython2.7-minimal.deb "${deb_url}/p/python2.7/libpython2.7-minimal_2.7.18-13ubuntu1.5_amd64.deb"
            wget -O /tmp/libpython2.7-stdlib.deb "${deb_url}/p/python2.7/libpython2.7-stdlib_2.7.18-13ubuntu1.5_amd64.deb"
            apt-get install --no-install-recommends -y /tmp/libpython2.7.deb /tmp/libpython2.7-minimal.deb /tmp/libpython2.7-stdlib.deb || \
              dpkg -i /tmp/libpython2.7.deb /tmp/libpython2.7-minimal.deb /tmp/libpython2.7-stdlib.deb
        fi
    else
        apt-get install --no-install-recommends -y libpython3.9
    fi

    # ubuntu 24.04 or above manually install libtinfo5 and libgconf-2-4
    if [ ${NEED_MANUAL_INSTALL} -eq 1 ]; then
        echo "Ubuntu 24.04 detected, manually downloading libtinfo5 from previous Ubuntu..."
        wget -O /tmp/libtinfo5.deb "${deb_url}/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb"
        wget -O /tmp/libgconf-2-4.deb "${deb_url}/g/gconf/libgconf-2-4_3.2.6-7ubuntu2_amd64.deb"
        wget -O /tmp/gconf2.deb "${deb_url}/g/gconf/gconf2-common_3.2.6-7ubuntu2_all.deb"
        apt-get install --no-install-recommends -y /tmp/libtinfo5.deb || dpkg -i /tmp/libtinfo5.deb
        apt-get install --no-install-recommends -y /tmp/gconf2.deb /tmp/libgconf-2-4.deb || dpkg -i /tmp/gconf2.deb /tmp/libgconf-2-4.deb
    fi
}


download_ccs() {
    mkdir -p ${TMP_DIR}
    cd ${TMP_DIR}

    if [ "${MAJOR_VER}" -ge 20 ]; then
        filename="CCS_${CCS_VERSION}_linux.zip"
        url="${CCS_URL}/${MAJOR_VER}.${MINOR_VER}.${PATCH_VER}/${filename}"
        [ ! -f "${filename}" ] && wget -c --no-check-certificate "${url}" -O "${filename}"
        unzip -q "${filename}"
        chmod -R 755 "CCS_${CCS_VERSION}_linux"

    elif [ "${MAJOR_VER}" -eq 12 ]; then
        filename="CCS${CCS_VERSION}_linux-x64.tar.gz"
        url="${CCS_URL}/${MAJOR_VER}.${MINOR_VER}.${PATCH_VER}/${filename}"
        [ ! -f "${filename}" ] && wget -c --no-check-certificate "${url}" -O "${filename}"
        tar -zxf "${filename}"
        chmod -R 755 "CCS${CCS_VERSION}_linux-x64"

    elif [ "${MAJOR_VER}" -lt 12 ]; then
        filename="CCS${CCS_VERSION}_linux-x64.tar.gz"
        url="${CCS_URL}/${CCS_VERSION}/${filename}"
        [ ! -f "${filename}" ] && wget -c --no-check-certificate "${url}" -O "${filename}"
        tar -zxf "${filename}"
        chmod -R 755 "CCS${CCS_VERSION}_linux-x64"
    fi
    cd /
}

fix_udev_rules() {
    # fix udev rules for TI devices
    # https://e2e.ti.com/support/tools/code-composer-studio-group/ccs/f/code-composer-studio-forum/1532443/codecomposer-installing-ccs-20-2-0-into-a-docker-container
    [ ! -e /usr/local/bin/udevadm ] && ln -s /bin/true /usr/local/bin/udevadm
    [ ! -e /sbin/start_udev ] && ln -s /bin/true /sbin/start_udev
    mkdir -p /etc/udev/rules.d
}

install_ccs() {
    download_ccs
    cd ${TMP_DIR}
    if [ "${MAJOR_VER}" -ge 20 ]; then
        dir="CCS_${CCS_VERSION}_linux"
        ccs_option_args=()
    else
        dir="CCS${CCS_VERSION}_linux-x64"
        ccs_option_args=(--install-BlackHawk false --install-Segger false)
    fi
    run_file="ccs_setup_${CCS_VERSION}.run"
    cd "${dir}"
    chmod +x "${run_file}"
    fix_udev_rules
    # if CCS_COMPONENTS is empty, throw error and exit
    if [ -z "${CCS_COMPONENTS}" ]; then
        echo "Error: CCS_COMPONENTS is not set, please use 'PF_ALL' to install all components."
        exit 1
    fi
    # if CCS_COMPONENTS is PF_ALL, use all available components (i.e., do not set --enable-components parameter)
    if [[ "${CCS_COMPONENTS,,}" == "pf_all" ]]; then
        ccs_module_args=()
    else
        # if CCS_COMPONENTS is not empty, use --enable-components parameter
        ccs_module_args=(--enable-components "${CCS_COMPONENTS}")
    fi
    # ./"${run_file}" --mode unattended --enable-components "${CCS_COMPONENTS}" --prefix "${CCS_DIR}" || true
    if ./"${run_file}" --mode unattended "${ccs_module_args[@]}" --prefix "${CCS_DIR}" "${ccs_option_args[@]}"; then
        echo "CCS installation completed successfully."
    else
        echo "CCS installation failed. Please check the logs for details."
        cat ${CCS_DIR}/ccs/install_logs/*/*.log
        exit 1
    fi
    # this step is essential not only to support debugging, but also to run the IDE on current Ubuntu environments. 
    ${CCS_DIR}/ccs/install_scripts/install_drivers.sh
    cd /
}

install_sys_bios() {
    if [ -z "${BIOS_VERSION}" ]; then
        echo "SYS/BIOS installation skipped as BIOS_VERSION is not set."
        return
    fi
    # if installing mmwave SDK's SYS_BIOS, no need to install SYS/BIOS separately
    BIOS_VERSION="${BIOS_VERSION//./_}"
    url="${SYS_BIOS_URL}/${BIOS_VERSION}/exports/bios_${BIOS_VERSION}.run"
    filename="${TMP_DIR}/bios_${BIOS_VERSION}.run"
    [ ! -f "${filename}" ] && wget -c --no-check-certificate "${url}" -O "${filename}"
    chmod +x "${filename}"
    # "${filename}" --mode unattended --prefix "${CCS_DIR}"
    if "${filename}" --mode unattended --prefix "${CCS_DIR}"; then
        echo "SYS/BIOS installation completed successfully."
    else
        echo "SYS/BIOS installation failed. Please check the logs for details."
        exit 1
    fi
}

install_mono() {
    if [ -z "${MMWSDK_VERSION}" ] || [ -z "${MMWSDK_COMPONENTS}" ]; then
        echo "mono installation skipped as MMWSDK_VERSION or MMWSDK_COMPONENTS is not set."
        return
    fi
    # only work for Ubuntu 20.04 and above
    # install Mono runtime for executing out2rprc.exe
    gpg --homedir /tmp --no-default-keyring \
      --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg \
      --keyserver hkp://keyserver.ubuntu.com:80 \
      --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" | \
      tee /etc/apt/sources.list.d/mono-official-stable.list
    apt-get update
    apt-get install --no-install-recommends -y mono-runtime
    dir_name="mmwave_sdk_${MMWSDK_VERSION//./_}"
cat << EOF > ${CCS_DIR}/${dir_name}/packages/scripts/ImageCreator/out2rprc/out2rprc
#!/bin/bash
/usr/bin/mono ${CCS_DIR}/${dir_name}/packages/scripts/ImageCreator/out2rprc/out2rprc.exe "\$@"
EOF
    chmod +x ${CCS_DIR}/${dir_name}/packages/scripts/ImageCreator/out2rprc/out2rprc
}

install_mmwave_sdk() {
    if [ -z "${MMWSDK_VERSION}" ] || [ -z "${MMWSDK_COMPONENTS}" ]; then
        echo "mmwave SDK installation skipped as MMWSDK_VERSION or MMWSDK_COMPONENTS is not set."
        return
    fi
    MMWSDK_VERSION_="${MMWSDK_VERSION//./_}"
    url="${MMWAVE_SDK_URL}/${MMWSDK_VERSION}/mmwave_sdk_${MMWSDK_VERSION_}-Linux-x86-Install.bin"
    filename="${TMP_DIR}/mmwave_sdk_${MMWSDK_VERSION_}-Linux-x86-Install.bin"
    [ ! -f "${filename}" ] && wget -c --no-check-certificate "${url}" -O "${filename}"
    chmod +x "${filename}"
    # if MMWSDK_COMPONENTS is ALL, use all available components (i.e., do not set --enable-components parameter)
    if [[ "${MMWSDK_COMPONENTS,,}" == "all" ]]; then
        sdk_module_args=()
    else
        # if MMWSDK_COMPONENTS is not empty, use --enable-components parameter
        sdk_module_args=(--enable-components "${MMWSDK_COMPONENTS}")
    fi
    if "${filename}" --mode unattended "${sdk_module_args[@]}" --prefix "${CCS_DIR}"; then
        echo "MMWAVE SDK installation completed successfully."
    else
        echo "MMWAVE SDK installation failed. Please check the logs for details."
        exit 1
    fi
    install_mono
}

init_ccs() {
    # initialize CCS workspace
    mkdir -p ${WORKSPACE_DIR}
    # CCS 12 and below: https://software-dl.ti.com/ccs/esd/documents/ccs_projects-command-line.html
    # CCS 20 and above: https://software-dl.ti.com/ccs/esd/documents/users_guide/ccs_project-command-line.html
    if [ "${MAJOR_VER}" -ge 20 ]; then
        ${CCS_DIR}/ccs/eclipse/ccs-server-cli.sh -noSplash -workspace "${WORKSPACE_DIR}" -application com.ti.ccs.apps.initialize -ccs.productDiscoveryPath "${CCS_DIR}"
        ${CCS_DIR}/ccs/eclipse/ccs-server-cli.sh -noSplash -workspace "${WORKSPACE_DIR}" -application com.ti.ccs.apps.initialize -rtsc.productDiscoveryPath "${CCS_DIR}"
        ${CCS_DIR}/ccs/eclipse/ccs-server-cli.sh -noSplash -workspace "${WORKSPACE_DIR}" -application com.ti.ccs.apps.inspect -ccs.products
    else
        # command-line message: SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder". This error does not affect any functionality
        # https://sir.ext.ti.com/jira/browse/EXT_EP-10874
        ${CCS_DIR}/ccs/eclipse/eclipse -nosplash -data "${WORKSPACE_DIR}" -application com.ti.common.core.initialize -ccs.productDiscoveryPath "${CCS_DIR}"
        ${CCS_DIR}/ccs/eclipse/eclipse -nosplash -data "${WORKSPACE_DIR}" -application com.ti.common.core.initialize -rtsc.productDiscoveryPath "${CCS_DIR}"
        ${CCS_DIR}/ccs/eclipse/eclipse -noSplash -data "${WORKSPACE_DIR}" -application com.ti.ccstudio.apps.inspect -ccs.product
    fi
}

clean() {
    rm -rf ${TMP_DIR}
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /tmp/*
    rm /configure.sh
}

if declare -f "$1" > /dev/null
then
  "$@"
else
  echo "'$1' is not a valid function!" >&2
  exit 1
fi
