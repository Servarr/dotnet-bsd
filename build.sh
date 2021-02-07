#! /bin/bash

set -e

## Runtime
git clone --depth 1 --branch v5.0.2 https://github.com/dotnet/runtime.git

DOTNET_DOCKER_TAG="mcr.microsoft.com/dotnet-buildtools/prereqs:$(curl -s https://raw.githubusercontent.com/dotnet/versions/master/build-info/docker/image-info.dotnet-dotnet-buildtools-prereqs-docker-master.json | jq -r '.repos[0].images[] | select(.platforms[0].dockerfile | contains("freebsd/11")) | .platforms[0].simpleTags[0]')"
docker run -e ROOTFS_DIR=/crossrootfs/x64 -v $(pwd)/runtime:/runtime $DOTNET_DOCKER_TAG /runtime/build.sh -c Release -cross -os freebsd

## AspNetCore
git clone --recursive --depth 1 --branch v5.0.2 https://github.com/dotnet/aspnetcore.git
git -C aspnetcore apply ../dotnet-bsd/patches/aspnetcore/0001-freebsd-support.patch

mkdir -p aspnetcore/artifacts/obj/Microsoft.AspNetCore.App.Runtime
cp runtime/artifacts/packages/Release/Shipping/dotnet-runtime-5.0.2-freebsd-x64.tar.gz aspnetcore/artifacts/obj/Microsoft.AspNetCore.App.Runtime

aspnetcore/build.sh -c Release -ci --os-name freebsd -pack -nobl /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99

## Installer
git clone --depth 1 --branch v5.0.102 https://github.com/dotnet/installer.git
git -C installer apply ../dotnet-bsd/patches/installer/0001-freebsd-support.patch

mkdir -p installer/artifacts/obj/redist/Release/downloads/
cp runtime/artifacts/packages/Release/Shipping/dotnet-runtime-*-freebsd-x64.tar.gz installer/artifacts/obj/redist/Release/downloads/
cp aspnetcore/artifacts/installers/Release/aspnetcore-runtime-* installer/artifacts/obj/redist/Release/downloads/

installer/build.sh -c Release -ci  -pack -nobl --runtime-id freebsd-x64 /p:OSName=freebsd /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99 /p:DISABLE_CROSSGEN=True /p:IncludeAspNetCoreRuntime=True
