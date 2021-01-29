#! /bin/bash

curl -fsSL https://get.docker.com | sh
apt install -y --no-install-recommends emacs-nox git nodejs npm jq

set -e

git clone --depth 1 --branch v5.0.2 https://github.com/dotnet/runtime.git

cd runtime
DOTNET_DOCKER_TAG="mcr.microsoft.com/dotnet-buildtools/prereqs:$(curl -s https://raw.githubusercontent.com/dotnet/versions/master/build-info/docker/image-info.dotnet-dotnet-buildtools-prereqs-docker-master.json | jq -r '.repos[0].images[] | select(.platforms[0].dockerfile | contains("freebsd/11")) | .platforms[0].simpleTags[0]')"
docker run -e ROOTFS_DIR=/crossrootfs/x64 -v $(pwd):/runtime $DOTNET_DOCKER_TAG /runtime/build.sh -c Release -cross -os freebsd

cd ..
git clone --recursive --depth 1 --branch v5.0.2 https://github.com/dotnet/aspnetcore.git
cd aspnetcore
mkdir -p artifacts/obj/Microsoft.AspNetCore.App.Runtime
cp ../runtime/artifacts/packages/Release/Shipping/dotnet-runtime-5.0.2-freebsd-x64.tar.gz artifacts/obj/Microsoft.AspNetCore.App.Runtime

git apply ../0001-freebsd-support.patch

./build.sh -c Release -ci --os-name freebsd -pack -nobl /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99

cd ..

#Can be omitted??
# git clone --depth 1 --branch v5.0.102 https://github.com/dotnet/sdk.git
# cd sdk
# Can be removed after 5.0.2
# git cherry-pick -n -m 1 80e42f16422352f725d78be72071781d8365a238

./build.sh -c Release -ci  -pack -nobl /p:OSName=freebsd /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99

cd ..
git clone --depth 1 --branch v5.0.102 https://github.com/dotnet/installer.git
cd installer

git apply ../0001-installer-bsd-support.patch

mkdir -p artifacts/obj/redist/Release/downloads/
cp ../runtime/artifacts/packages/Release/Shipping/dotnet-runtime-*-freebsd-x64.tar.gz artifacts/obj/redist/Release/downloads/
cp ../aspnetcore/artifacts/installers/Release/aspnetcore-runtime-* artifacts/obj/redist/Release/downloads/

./build.sh -c Release -ci  -pack -nobl --runtime-id freebsd-x64 /p:OSName=freebsd /p:CrossgenOutput=false /p:OfficialBuildId=$(date +%Y%m%d)-99 /p:DISABLE_CROSSGEN=True /p:IncludeAspNetCoreRuntime=True
