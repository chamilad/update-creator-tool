#!/bin/bash

target="wum-uc.go"

function showUsageAndExit() {
    echo "Insufficient or invalid options provided"
    echo
    echo "Usage: "$'\e[1m'"./build.sh -v [build-version] -f"$'\e[0m'
    echo -en "  -v\t"
    echo "[REQUIRED] Build version. If not specified a default value will be used."
    echo -en "  -f\t"
    echo "[OPTIONAL] Cross compile for all the list of platforms. If not specified, the specified target file will be cross compiled only for the auto detected native platform."

    echo
    echo "Ex: "$'\e[1m'"./build.sh -v 1.0.0 -f"$'\e[0m'" - Builds Update Creator Tool for version 1.0.0 for all the platforms"
    echo
    exit 1
}

function detectPlatformSpecificBuild() {
    platform=$(uname -s)
    if [[ "${platform}" == "Linux" ]]; then
        platforms="linux/386/linux/i586 linux/amd64/linux/x64"
    elif [[ "${platform}" == "Darwin" ]]; then
        platforms="darwin/amd64/macosx/x64"
    else
        platforms="windows/386/windows/i586 windows/amd64/windows/x64"
    fi
}

while getopts :v:f FLAG; do
  case $FLAG in
    v)
      build_version=$OPTARG
      ;;
    f)
      full_build="true"
      ;;
    \?)
      showUsageAndExit
      ;;
  esac
done

if [ -z "$build_version" ]
then
  echo "Build version is needed. "
  showUsageAndExit
fi

echo "Cleaning build path build/target..."
rm -rf build/target

type glide >/dev/null 2>&1 || { echo >&2 "Glide dependency management is needed to build the Update Creator Tool (https://glide.sh/).  Aborting."; exit 1; }

echo "Setting up dependencies..."
glide install
echo

if [ "${full_build}" == "true" ]; then
    echo "Building "$'\e[1m'"Update Creator Tool"$'\e[0m'" for all platforms..."
    platforms="darwin/amd64/macosx/x64 linux/386/linux/i586 linux/amd64/linux/x64 windows/386/windows/i586 windows/amd64/windows/x64"
else
    detectPlatformSpecificBuild
    echo "Building "$'\e[1m'"Update Creator Tool"$'\e[0m'" for detected "$'\e[1m'"${platform}"$'\e[0m'" platform..."
fi

for platform in ${platforms}
do
    split=(${platform//\// })
    goos=${split[0]}
    goarch=${split[1]}
    pos=${split[2]}
    parch=${split[3]}

    echo -en "\t - ${goos}/${goarch}..."

    # ensure output file name
    output="${binary}"
    test "${output}" || output="$(basename ${target} | sed 's/\.go//')"

    # add exe to windows output
    [[ "windows" == "${goos}" ]] && output="${output}.exe"

    zipfile="wum-uc-${build_version}-${pos}-${parch}"
    zipdir="$(dirname ${target})/build/target/${zipfile}"
    mkdir -p ${zipdir}

    cp -r "$(dirname ${target})/resources" ${zipdir}
    cp -r "$(dirname ${target})/README.md" ${zipdir}
    cp -r "$(dirname ${target})/LICENSE.txt" ${zipdir}

    # set destination path for binary
    destination="${zipdir}/bin/${output}"

    #echo "GOOS=$goos GOARCH=$goarch go build -x -o $destination $target"
    GOOS=${goos} GOARCH=${goarch} go build -ldflags "-X main.version=${build_version} -X 'main.buildDate=$(date -u '+%Y-%m-%d %H:%M:%S')'" -o ${destination} ${target}

    pwd=`pwd`
    cd "$(dirname ${target})/build/target"
    #zip -r "${zipfile}.zip" ${zipfile} > /dev/null 2>&1
    tar czf "${zipfile}.tar.gz" ${zipfile} > /dev/null 2>&1
    rm -rf ${zipfile}
    cd ${pwd}
    echo -en $'\e[1m\u2714\e[0m'
    echo
done

echo "Build complete!"