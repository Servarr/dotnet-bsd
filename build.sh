#! /bin/bash

set -e

RUNTIMETAG=v5.0.3
SDKTAG=v5.0.103

## Runtime
git clone --depth 1 --branch $RUNTIMETAG https://github.com/dotnet/runtime.git
sed -i '/\/dnceng\/internal\//d' runtime/NuGet.config

DOTNET_DOCKER_TAG="mcr.microsoft.com/dotnet-buildtools/prereqs:$(curl -s https://raw.githubusercontent.com/dotnet/versions/master/build-info/docker/image-info.dotnet-dotnet-buildtools-prereqs-docker-master.json | jq -r '.repos[0].images[] | select(.platforms[0].dockerfile | contains("freebsd/11")) | .platforms[0].simpleTags[0]')"
docker run -e ROOTFS_DIR=/crossrootfs/x64 -v $(pwd)/runtime:/runtime $DOTNET_DOCKER_TAG /runtime/build.sh -c Release -cross -os freebsd

## AspNetCore
git clone --recursive --depth 1 --branch $RUNTIMETAG https://github.com/dotnet/aspnetcore.git
git -C aspnetcore apply ../dotnet-bsd/patches/aspnetcore/0001-freebsd-support.patch
dotnet nuget add source ../runtime/artifacts/packages/Release/Shipping --name runtime --configfile aspnetcore/NuGet.config
sed -i '/\/dnceng\/internal\//d' aspnetcore/NuGet.config

mkdir -p aspnetcore/artifacts/obj/Microsoft.AspNetCore.App.Runtime
cp runtime/artifacts/packages/Release/Shipping/dotnet-runtime-5.*-freebsd-x64.tar.gz aspnetcore/artifacts/obj/Microsoft.AspNetCore.App.Runtime

aspnetcore/build.sh -c Release -ci --os-name freebsd -pack -nobl /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99

## Installer
git clone --depth 1 --branch $SDKTAG https://github.com/dotnet/installer.git
git -C installer apply ../dotnet-bsd/patches/installer/0001-freebsd-support.patch
dotnet nuget remove source msbuild --configfile installer/NuGet.config
dotnet nuget remove source nuget-build --configfile installer/NuGet.config
dotnet nuget add source ../runtime/artifacts/packages/Release/Shipping --name runtime --configfile installer/NuGet.config
dotnet nuget add source ../aspnetcore/artifacts/packages/Release/Shipping --name aspnetcore --configfile installer/NuGet.config
sed -i '/\/dnceng\/internal\//d' installer/NuGet.config

mkdir -p installer/artifacts/obj/redist/Release/downloads/
cp runtime/artifacts/packages/Release/Shipping/dotnet-runtime-*-freebsd-x64.tar.gz installer/artifacts/obj/redist/Release/downloads/
cp aspnetcore/artifacts/installers/Release/aspnetcore-runtime-* installer/artifacts/obj/redist/Release/downloads/

installer/build.sh -c Release -ci  -pack -nobl --runtime-id freebsd-x64 /p:OSName=freebsd /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99 /p:DISABLE_CROSSGEN=True /p:IncludeAspNetCoreRuntime=True
