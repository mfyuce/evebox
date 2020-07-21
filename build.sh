#! /bin/bash

set -e

DOCKER_NAME="jasonish/evebox"
BRANCH_PREFIX=$(git rev-parse --abbrev-ref HEAD | awk '{split($0,a,"/"); print a[1]}')

BUILD_REV=$(git rev-parse --short HEAD)
export BUILD_REV

build_webapp() {
    DOCKERFILE="./docker/builder/Dockerfile.musl"
    TAG=${BUILDER_TAG:-"evebox/builder:webapp"}
    docker build ${CACHE_FROM} --rm \
           --build-arg REAL_UID="$(id -u)" \
           --build-arg REAL_GID="$(id -g)" \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
           -v "$(pwd):/src" \
           -w /src/webapp \
           -e REAL_UID="$(id -u)" \
           -e REAL_GID="$(id -g)" \
           -e BUILD_REV="${BUILD_REV}" \
           ${TAG} make
}

# Linux - x86_64
build_linux() {
    DOCKERFILE="./docker/builder/Dockerfile.musl"
    TAG=${BUILDER_TAG:-"evebox/builder:musl"}
    docker build --rm \
           --build-arg REAL_UID="$(id -u)" \
           --build-arg REAL_GID="$(id -g)" \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
           -v "$(pwd):/src" \
           -v "$HOME/.cargo:/home/builder/.cargo" \
           -w /src \
           -e REAL_UID="$(id -u)" \
           -e REAL_GID="$(id -g)" \
           -e BUILD_REV="${BUILD_REV}" \
           -e TARGET="x86_64-unknown-linux-musl" \
           ${TAG} make dist rpm deb
}

build_linux_armv7() {
    DOCKERFILE="./docker/builder/Dockerfile.armv7"
    TAG=${BUILDER_TAG:-"evebox/builder:armv7"}
    docker build --rm \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
         -v "$(pwd)/target:/src/target" \
         -v "$(pwd)/dist:/src/dist" \
         -v /var/run/docker.sock:/var/run/docker.sock \
         -w /src \
         -e REAL_UID="$(id -u)" \
         -e REAL_GID="$(id -g)" \
         -e BUILD_REV="${BUILD_REV}" \
         -e TARGET="armv7-unknown-linux-musleabihf" \
         -e CARGO="cross" \
         ${TAG} make dist
}

build_linux_armv6() {
    DOCKERFILE="./docker/builder/Dockerfile.armv6"
    TAG=${BUILDER_TAG:-"evebox/builder:armv6"}
    docker build --rm \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
         -v "$(pwd)/target:/src/target" \
         -v "$(pwd)/dist:/src/dist" \
         -v /var/run/docker.sock:/var/run/docker.sock \
         -w /src \
         -e REAL_UID="$(id -u)" \
         -e REAL_GID="$(id -g)" \
         -e BUILD_REV="${BUILD_REV}" \
         -e TARGET="arm-unknown-linux-gnueabihf" \
         -e CARGO="cross" \
         ${TAG} make dist
}

build_windows() {
    TAG=${BUILDER_TAG:-"evebox/builder:windows"}
    DOCKERFILE="./docker/builder/Dockerfile.windows"
    docker build ${CACHE_FROM} --rm \
           --build-arg REAL_UID="$(id -u)" \
           --build-arg REAL_GID="$(id -g)" \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
           -v "$(pwd):/src" \
           -w /src \
           -e REAL_UID="$(id -u)" \
           -e REAL_GID="$(id -g)" \
           -e CC=x86_64-w64-mingw32-gcc \
           -e TARGET=x86_64-pc-windows-gnu \
           -e BUILD_REV="${BUILD_REV}" \
           ${TAG} make dist
}

build_macos() {
    TAG=${BUILDER_TAG:-"evebox/builder:macos"}
    DOCKERFILE="./docker/builder/Dockerfile.macos"
    docker build ${CACHE_FROM} --rm \
           --build-arg REAL_UID="$(id -u)" \
           --build-arg REAL_GID="$(id -g)" \
           --cache-from ${TAG} \
	   -t ${TAG} \
	   -f ${DOCKERFILE} .
    docker run ${IT} --rm \
           -v "$(pwd):/src" \
           -w /src \
           -e REAL_UID="$(id -u)" \
           -e REAL_GID="$(id -g)" \
           -e CC=o64-clang \
           -e TARGET=x86_64-apple-darwin \
           -e BUILD_REV="${BUILD_REV}" \
           ${TAG} make dist
}

build_docker() {
    docker buildx build \
           --build-arg "BUILD_REV=${BUILD_REV}" \
           --build-arg "SRC=./dist/evebox-latest-linux-x64/evebox" \
           --load \
           --platform linux/amd64 \
           -t ${DOCKER_NAME}:${BRANCH_PREFIX}-x86_64 \
           -f docker/Dockerfile .


    docker buildx build \
           --build-arg "BUILD_REV=${BUILD_REV}" \
           --build-arg "SRC=./dist/${BRANCH_PREFIX}-build-armv7/evebox-latest-linux-arm/evebox" \
           --load \
           --platform linux/arm/v7 \
           -t ${DOCKER_NAME}:${BRANCH_PREFIX}-armv7 \
           -f docker/Dockerfile .

    docker buildx build \
           --build-arg "BUILD_REV=${BUILD_REV}" \
           --build-arg "SRC=./dist/${BRANCH_PREFIX}-build-armv6/evebox-latest-linux-arm/evebox" \
           --load \
           --platform linux/arm/v6 \
           -t ${DOCKER_NAME}:${BRANCH_PREFIX}-armv6 \
           -f docker/Dockerfile .
  }

  docker_push() {
      docker push ${DOCKER_NAME}:${BRANCH_PREFIX}-x86_64
      docker push ${DOCKER_NAME}:${BRANCH_PREFIX}-armv7
      docker push ${DOCKER_NAME}:${BRANCH_PREFIX}-armv6
      docker manifest create -a ${DOCKER_NAME}:${BRANCH_PREFIX} \
             ${DOCKER_NAME}:${BRANCH_PREFIX}-x86_64 \
             ${DOCKER_NAME}:${BRANCH_PREFIX}-armv7\
             ${DOCKER_NAME}:${BRANCH_PREFIX}-armv6
      docker manifest push --purge ${DOCKER_NAME}:${BRANCH_PREFIX}
}

build_all() {
    rm -rf dist

    build_webapp
    ./docker.sh release-linux
    ./docker.sh release-windows
    ./docker.sh release-macos
    ./docker.sh release-armv7
    ./docker.sh release-armv6
}

push() {
    (cd dist && sha256sum *.zip *.rpm *.deb > CHECKSUMS.txt)

    if [ "${EVEBOX_RSYNC_PUSH_DEST}" ]; then
        rsync -av \
              --filter "+ *.rpm" \
              --filter "+ *.deb" \
              --filter "+ *.zip" \
              --filter "+ CHECKSUMS.txt" \
              --filter "- *" \
              dist/ \
              "${EVEBOX_RSYNC_PUSH_DEST}"
    else
        echo "error: EVEBOX_RSYNC_PUSH_DEST environment variable not set"
    fi
}

case "$1" in
    webapp)
        build_webapp
        ;;

    linux)
        build_linux
        ;;

    linux-armv7)
        build_linux_armv7
        ;;

    linux-armv6)
        build_linux_armv6
        ;;

    windows)
        build_windows
        ;;

    macos)
        build_macos
        ;;

    docker)
        build_docker
        ;;

    docker-push)
        build_docker
        docker_push
        ;;

    all)
        build_webapp
        build_linux
        build_linux_armv7
        build_linux_armv6
        build_windows
        build_macos
        build_docker
        ;;

    *)
        cat <<EOF
usage: $0 <command>

Commands:
    release-linux      Build x86_64 Linux release - zip/deb/rpm.
    release-armv7       Build armv7 Linux Release (RPi) - zip
    release-armv6      Build armv6 Linux Release (RPi) - zip
    all
EOF
        exit 1
        ;;
esac
