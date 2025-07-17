#!/bin/bash

set -e

# use comma as delimiter, support both absolute and relative paths
projects_filename="${1}"
# build type configuration
build_type="${2:-Release}"
# directory path for CCS project files in container (must be mounted to a host directory when container starts)
# note: CCS build results will always be placed in ${WORKSPACE_DIR}
projects_dir="/ccs_projects"

function show_help()
{
    echo "Usage: $0 <project_location(s)> [build_type]"
    echo "  project_location(s): Comma-separated list of locations."
    echo "    Locations can be absolute or relative to ${projects_dir} (path inside the container)."
    echo "    Supports locations can be *.projectspec files or directories containing CCS projects"
    echo "    Referenced projects are imported automatically."
    echo "  build_type: Build type: 'Release' or 'Debug'."
    echo "    Default is 'Release'."
    echo "  Note: WORKSPACE_DIR (Directory where the build results will be stored) is set to ${WORKSPACE_DIR} in the container."
    echo "    If you want to store the build results in your host machine, make sure to mount a volume to this directory."
    exit 1
}

# check if project file is provided
if [ -z "${projects_filename}" ]; then
    echo "Error: No project file specified."
    show_help
fi

# exit if the directory contains no files
if [ -z "$(ls -A ${projects_dir})" ]; then
    echo "No files found in ccstudio project dir ${projects_dir}."
    echo "Make sure to mount your CCS project directory to ${projects_dir} in the container."
    echo "For example, use -v /path/to/your/ccs_projects:${projects_dir} when running the container."
    exit 0
fi

function run_ccs()
{
    if command -v ccs-server-cli.sh &> /dev/null; then
        CCS_20=1
    elif command -v eclipse &> /dev/null; then
        CCS_20=0
    else
        echo "CCS command not found. Please ensure Code Composer Studio is installed and in your PATH."
        exit 1
    fi
    # define file extension array
    file_exts=("*.ccsproject" "*.cproject" "*.project" "*.projectspec")
    name_expr=()
    for ext in "${file_exts[@]}"; do
        name_expr+=( -name "${ext}" -o )
    done
    # use array slicing to exclude the last -o
    name_expr=( "${name_expr[@]:0:${#name_expr[@]}-1}" )

    find "${projects_dir}" -type f \( "${name_expr[@]}" \) -print0 | while IFS= read -r -d '' file; do
        # https://e2e.ti.com/support/tools/code-composer-studio-group/ccs/f/code-composer-studio-forum/480411/ccs-6-1-1-how-to-edit-ti_products_dir
        # ${TI_PRODUCTS_DIR} always points to the ti folder under the user's home directory when CCS was installed
        #   even if another directory is specified during installation, it still cannot be modified
        #   using -ccs.definePathVariable TI_PRODUCTS_DIR /opt/ti also can not work
        # so we need to replace ${TI_PRODUCTS_DIR} in existing .projectspec files with ${CCS_INSTALL_ROOT}/.. (assuming CCS and TI products are installed in the same directory)
        sed -i 's|${TI_PRODUCTS_DIR}|${CCS_INSTALL_ROOT}/..|g' "${file}"
        # echo "Patching ${file}: \${TI_PRODUCTS_DIR} replaced with \${CCS_INSTALL_ROOT}/.."
        sed -i "s|\${WORKSPACE_LOC}|${WORKSPACE_DIR}|g" "${file}"
        # echo "Patching ${file}: \${WORKSPACE_LOC} replaced with ${WORKSPACE_DIR}"
        # sed -i 's|\.exe||g' "${file}"
    done

    # find files containing .exe and remind users to manually modify them
    find "${projects_dir}" -type f \( "${name_expr[@]}" \) -print0 | while IFS= read -r -d '' file; do
        if grep -q '\.exe ' "${file}"; then
            echo "Found '.exe' in file: ${file}"
            grep -n '\.exe ' "${file}"
            echo "Please review and remove for Linux compatibility."
        fi
    done
    # initialize command arguments array
    ccs_import_args=()
    # parse project path string (comma-separated)
    IFS=',' read -ra PROJECTS <<< "${projects_filename}"
    # build arguments for each project
    for project in "${PROJECTS[@]}"; do
        if [ -e "${project}" ]; then
            ccs_import_args+=("-ccs.location" "${project}")
        elif [ -e "${projects_dir}/${project}" ]; then
            ccs_import_args+=("-ccs.location" "${projects_dir}/${project}")
        else
            echo "Warning: Project not found: ${project}"
        fi
    done
    if [ $CCS_20 -eq 1 ]; then
        ccs-server-cli.sh -noSplash -workspace "${WORKSPACE_DIR}" \
          -application com.ti.ccs.apps.projectImport -ccs.copyIntoWorkspace \
          -ccs.autoImportReferencedProjects -ccs.referencedProjectSearchDirectory "${projects_dir}" \
          "${ccs_import_args[@]}"
        ccs-server-cli.sh -noSplash -workspace "${WORKSPACE_DIR}" \
          -application com.ti.ccs.apps.projectBuild -ccs.configuration "${build_type}" -ccs.workspace
    elif [ $CCS_20 -eq 0 ]; then
        eclipse -noSplash -data "${WORKSPACE_DIR}" \
          -application com.ti.ccstudio.apps.projectImport -ccs.copyIntoWorkspace \
          -ccs.autoImportReferencedProjects -ccs.referencedProjectSearchDirectory "${projects_dir}" \
          "${ccs_import_args[@]}"
        eclipse -noSplash -data "${WORKSPACE_DIR}" \
          -application com.ti.ccstudio.apps.projectBuild -ccs.configuration "${build_type}" -ccs.workspace
    fi
    # display all .bin, .out and *.xe* files
    find "${WORKSPACE_DIR}" -type f \( -name "*.bin" -o -name "*.out" -o -name "*.xe*" \) -exec ls -lah {} \;
}

run_ccs || show_help
