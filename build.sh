#!/bin/bash

set -e

# directory path for CCS project files in host machine
test_dir="./mmw_oob"
# directory path for CCS project files in container (must be mounted to a host directory)
projects_dir="/ccs_projects"

make list

if command -v docker-compose &> /dev/null ; then
    make gen_compose
    docker-compose -f docker-compose.yaml --parallel 3 build
elif command -v docker compose &> /dev/null ; then
    make gen_compose
    docker compose -f docker-compose.yaml --parallel 3 build
else
    make all
fi

docker images

function test()
{
    # images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^whuzfb/ccstudio:.*")
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^whuzfb/ccstudio:.*mmw$")
    for image in $images; do
        echo "Image: ${image}"
        docker run -v ${test_dir}:${projects_dir} -it --rm --name ccstudio_${image##*:} ${image} "out_of_box_6843_isk_mss.projectspec" "Debug"
        docker push "${image}"
    done
}

# test
