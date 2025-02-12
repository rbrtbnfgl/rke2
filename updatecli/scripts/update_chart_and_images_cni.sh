#!/bin/bash

info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

update_chart_version() {
    info "updating chart ${1} in ${CHART_VERSIONS_FILE}"
    CURRENT_VERSION=$(yq -r '.charts[] | select(.filename == "/charts/'"${1}"'.yaml") | .version' ${CHART_VERSIONS_FILE})
    NEW_VERSION=${2}
    if [ "${CURRENT_VERSION}" != "${NEW_VERSION}" ]; then
        info "found version ${CURRENT_VERSION}, updating to ${NEW_VERSION}"
        chart_updated=true
        if test "$DRY_RUN" == "false"; then
            sed -i "s/${CURRENT_VERSION}/${NEW_VERSION}/g" ${CHART_VERSIONS_FILE}
        else
            info "dry-run is enabled, no changes will occur"
        fi
    else
        info "no new version found"
    fi
}

update_chart_images() {
    info "downloading chart ${1} version ${2} to extract image versions"
    tempdir=$(mktemp -d)
    CHART_URL="https://github.com/rancher/rke2-charts/raw/main/assets/${1}/${1}-${2}.tgz"
    curl -s -L -o $tempdir/${1}-${2}.tgz ${CHART_URL}
    if test "$chart_updated" == "true"; then
        # get all images and tags for the latest constraint
	cni=$(echo "${1}" | sed -nE 's/rke2-(.*)/\1/p')
	IMAGES_TAG=$(helm template $tempdir/${1}-${2}.tgz | grep -E image:)
	LIST_IMAGES=""
        while IFS= read -r line ; do 
	      IMAGE=$(echo "${line}" | sed -nE 's/image: (.*)/\1/p' | sed 's/\//\\\//g' | tr -dc '[:alnum:]:.\-/\\')
	      LIST_IMAGES=$(echo "$LIST_IMAGES\${REGISTRY}/${IMAGE}\n")
	done <<< "$IMAGES_TAG"
        if test "$DRY_RUN" == "false"; then
              awk -v images_list="$LIST_IMAGES" "BEGIN{split(images_list, images_array, \"\n\"); for (i in images_array) {n = split(images_array[i], image_tag, \":\"); if (n == 2) images_list_array[image_tag[1]] = image_tag[2];}}/.*build\/images-${cni}.txt.*/ {print; getline; while (\$1 != \"EOF\") { n = split(\$1, current_image, \":\"); if (n == 2) print \"    \"current_image[1]\":\"images_list_array[current_image[1]]; getline;}}; {print}" ${CHART_AIRGAP_IMAGES_FILE} > $tempdir/images_file.sh
              cp $tempdir/images_file.sh ${CHART_AIRGAP_IMAGES_FILE}
        else
              info "dry-run is enabled, no changes will occur"
         fi
    else
        info "no new version found"
    fi
    # removing downloaded artifacts
    rm -rf $tempdir/
}

CHART_VERSIONS_FILE="charts/chart_versions.yaml"
CHART_AIRGAP_IMAGES_FILE="scripts/build-images"


CHART_NAME=${1}
CHART_VERSION=${2}
chart_updated=false

update_chart_version ${CHART_NAME} ${CHART_VERSION}
update_chart_images ${CHART_NAME} ${CHART_VERSION}
