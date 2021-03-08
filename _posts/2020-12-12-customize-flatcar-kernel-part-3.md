---
layout: post
title: 'Customize the FlatCar Kernel - Part 3 - Easy Kernel Modules using Forklift'
date: '20-12-12T01:19:33-08:00'
cover: '/assets/images/cover_flatcar.png'
subclass: 'post tag-post'
tags:
- flatcar
- github
- linux
- kernel

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

It's been a while since I discussed building kernel modules for CoreOS (in [Part 1](https://blog.thesparktree.com/customize-coreos-kernel-part-1) and [Part 2](https://blog.thesparktree.com/customize-coreos-kernel-part-2))
and lot's has changed in the CoreOS world. [CoreOS was acquired by RedHat](https://www.redhat.com/en/about/press-releases/red-hat-acquire-coreos-expanding-its-kubernetes-and-containers-leadership) and eventually replaced by
[CoreOS Fedora](https://docs.fedoraproject.org/en-US/fedora-coreos/faq/) but the original project lives on in [FlatCar linux](https://kinvolk.io/blog/2018/03/announcing-the-flatcar-linux-project/),
a fork of CoreOS.

Since those last posts, I've also started using a dedicated GPU to do hardware transcoding of video files. Unfortunately
using a dedicated NVidia GPU means I need to change the process I use for building kernel modules.

---

# Building a Developer Container

As with CoreOS, the first step is building a [FlatCar Development Container](https://docs.flatcar-linux.org/os/kernel-modules/).

<div class="github-widget" data-repo="mediadepot/docker-flatcar-developer"></div>

With the help of Github Actions, I've created a repository that will automatically generate versioned Docker images for each
[FlatCar Release Channel](https://www.flatcar-linux.org/releases/)

```bash
curl https://stable.release.flatcar-linux.net/amd64-usr/current/version.txt -o version.txt
cat version.txt
export $(cat version.txt | xargs)

echo "Download Developer Container"
curl -L https://stable.release.flatcar-linux.net/amd64-usr/${FLATCAR_VERSION}/flatcar_developer_container.bin.bz2 -o flatcar_developer_container.bin.bz2
bunzip2 -k flatcar_developer_container.bin.bz2
mkdir ${FLATCAR_VERSION}
sudo mount -o ro,loop,offset=2097152 flatcar_developer_container.bin ${FLATCAR_VERSION}
sudo tar -cp --one-file-system -C ${FLATCAR_VERSION} . | docker import - mediadepot/flatcar-developer:${FLATCAR_VERSION}
rm -rf flatcar_developer_container.bin flatcar_developer_container.bin.bz2

docker push mediadepot/flatcar-developer:${FLATCAR_VERSION}
```

While it's useful to have the Flatcar Development Container easily accessible on Docker Hub, it's not functional out of
the box for building Kernel Modules. At the very least we need to provide the kernel source within the container.
We need to be careful that the source code for the kernel matches the linux kernel deployed with the specific version of
Flatcar.

To do that, we'll use a [Dockerfile](https://github.com/mediadepot/docker-flatcar-developer/blob/master/Dockerfile).

```Dockerfile
ARG FLATCAR_VERSION
FROM mediadepot/flatcar-developer:${FLATCAR_VERSION}
LABEL maintainer="Jason Kulatunga <jason@thesparktree.com>"
ARG FLATCAR_VERSION
ARG FLATCAR_BUILD

# Create a Flatcar Linux Developer image as defined in:
# https://docs.flatcar-linux.org/os/kernel-modules/

RUN emerge-gitclone \
    && export $(cat /usr/share/coreos/release | xargs) \
    && export OVERLAY_VERSION="flatcar-${FLATCAR_BUILD}" \
    && export PORTAGE_VERSION="flatcar-${FLATCAR_BUILD}" \
    && env \
    && git -C /var/lib/portage/coreos-overlay checkout "$OVERLAY_VERSION" \
    && git -C /var/lib/portage/portage-stable checkout "$PORTAGE_VERSION"

# try to use pre-built binaries and fall back to building from source
RUN emerge -gKq --jobs 4 --load-average 4 coreos-sources || echo "failed to download binaries, fallback build from source:" && emerge -q --jobs 4 --load-average 4 coreos-sources

# Prepare the filesystem
# KERNEL_VERSION is determined from kernel source, not running kernel.
# see https://superuser.com/questions/504684/is-the-version-of-the-linux-kernel-listed-in-the-source-some-where
RUN cp /usr/lib64/modules/$(ls /usr/lib64/modules)/build/.config /usr/src/linux/ \
    && make -C /usr/src/linux modules_prepare \
    && cp /usr/lib64/modules/$(ls /usr/lib64/modules)/build/Module.symvers /usr/src/linux/
```

# Pre-Compiling Nvidia Kernel Driver

Now that we have a Docker image matching our Flatcar version, the next thing we need to do is build the Nvidia Drivers against
the kernel source. Again, we'll be using Github Actions to pre-build our Docker image, meaning we need to take special care
when we compile the driver, since Docker images share a kernel with the host machine, and the Github Action server is
definitely running a kernel that is different from the kernel we'll be running on our actual Flatcar host.

<div class="github-widget" data-repo="mediadepot/docker-flatcar-nvidia-driver"></div>

```bash

./nvidia-installer -s -n \
  --kernel-name="${KERNEL_VERSION}" \
  --kernel-source-path=/usr/src/linux \
  --no-check-for-alternate-installs \
  --no-opengl-files \
  --no-distro-scripts \
  --kernel-install-path="/$PWD" \
  --log-file-name="$PWD"/nvidia-installer.log || true

```

The important flags for compiling the Nvidia driver for a different kernel are the following:

- `--kernel-name` - build and install the NVIDIA kernel module for the non-running kernel specified by KERNEL-NAME
    (KERNEL-NAME should be the output of `uname -r` when the target kernel is actually running).
- `--kernel-source-path` - The directory containing the kernel source files that should be used when compiling the NVIDIA kernel module.

Now that we can pre-compile the Nvidia driver for Flatcar, we need a way to download the drivers and install them automatically
since Flatcar is an auto-updating OS.

# Forklift - Auto Updating Kernel Drivers

<div class="github-widget" data-repo="mediadepot/flatcar-forklift"></div>

Forklift is the last part of the equation. It's a Systemd service and a simple script, which runs automatically on startup
pulling the relevant Docker image containing a Nvidia driver and matches the version of Flatcar, caches the drivers to a specific folder, and then
installs the kernel module.

# Extending Forklift

There's nothing unique about this pattern, it can be used to continuously build any other kernel module (eg. wireguard), and
contributions are welcome!


