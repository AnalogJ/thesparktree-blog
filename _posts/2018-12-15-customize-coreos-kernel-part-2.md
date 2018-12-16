---
layout: post
title: 'Customize CoreOS Kernel - Part 2 - Kernel SDK'
date: '18-12-09T01:19:33-08:00'
cover: '/assets/images/cover_coreos.png'
subclass: 'post tag-post'
tags:
- homeserver
- coreos
- github
- linux
- kernel


navigation: True
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

After running into a roadblock while attempting to [build the Intel I915 driver as a kernel module](./customize-coreos-kernel-part-1) for CoreOS,
it became clear that we would need to build a completely custom CoreOS kernel with the drivers and features we need enabled.

Thankfully the CoreOS developers have provided us with a set of tools and documentation to help make this process a bit easier:

[CoreOS Container Linux developer SDK](https://coreos.com/os/docs/latest/sdk-modifying-coreos.html)

CoreOS is all open source and made up of a couple dozen git repositories, which are then glued together and compiled by the tools included in the
SDK.

The SDK tools are meant to be installed on a computer running Linux, however to make things easier for myself I created a CentOS VM using a
simple Vagrantfile:

```vagrantfile

Vagrant.configure("2") do |config|
    config.vm.box = "centos/7"

    config.vm.provider "virtualbox" do |v|
        v.name = "coreos_builder"
        v.memory = 11264
        v.cpus = 4
    end

    config.vm.provision "shell", path: "provisioner.sh"
end

```

You'll want to give as much CPU and RAM as you can, as the build and compilation steps are time consuming (I'm talking multiple hours here).

# Building Vanilla CoreOS

The first thing I want to do is build a vanilla version of CoreOS without any changes. To do this we'll create a `provisioner.sh` script
and populate it as follows:

```bash
#!/usr/bin/env bash

## Prerequisites

yum install -y \
    ca-certificates \
    curl \
    git \
    bzip2

cd /usr/bin && \
    curl -L -o cork https://github.com/coreos/mantle/releases/download/v0.11.1/cork-0.11.1-amd64 && \
    chmod +x cork && \
    which cork

## Using Cork
# https://coreos.com/os/docs/latest/sdk-modifying-coreos.html

exec sudo -u vagrant /bin/sh - << 'EOF'
whoami
git config --global user.email "jason@thesparktree.com" && \
git config --global user.name "Jason Kulatunga"

mkdir -p ~/coreos-sdk
cd ~/coreos-sdk
cork create

cork enter
grep NAME /etc/os-release

./set_shared_user_password.sh 12345
./setup_board
./build_packages
./build_image

EOF

```

As you can see the `Prerequsites` section is pretty straight forward, we download & install the SDK dependencies as listed
in their documentation and download the `cork` tool.

Then the script gets a bit interesting. We tell Vagrant to execute the following commands as the `vagrant` user, rather than
the default `root` user used during provisioning. This is due to the fact that the `cork` tool [expects to be run as a regular user
not root](https://github.com/coreos/mantle/issues/958).

So we'll verify that we're running as `vagrant` using `whoami`, then configure the `git` tool

Then we'll go back to the steps mentioned in the SDK guide, creating a folder for the SDK to manage, and finally running the `cork`
commands.

- `cork create` will download and unpack the SDK into the current directory
- `cork enter` will enter a [`chroot`](https://wiki.archlinux.org/index.php/chroot) with additional SDK tools that we can then use to
download & compile our coreos image

Now that we have a `Vagrantfile` and `provisioner.sh` script, we can verify our VM configuration and run `vagrant up` to build and provision
our VM.

`vagrant up` took more than 4 hours to complete on my machine (how long did it take you?). Once complete, you should be greeted with a success
message that looks like the following:

![sdk complete]({{ site.url }}/assets/images/coreos/sdk_complete.png)

At this point we've verified that our base tooling is installed correctly, and that we can build CoreOS images. Now we need to start
our kernel customizations.

## Forking CoreOS

As I mentioned earlier, CoreOS is broken up into a couple dozen git repos, but the primary repo is called [`coreos/manifest`](https://github.com/coreos/manifest).

Looking at the [master.xml](https://github.com/coreos/manifest/blob/master/master.xml) makes it clear why `manifest` is so
important: **It references all the other git repos that are used when building CoreOS**

The first thing we're going to do is fork and clone repo so that we can customize the repos used to ones that contain our changes.

I forked [coreos/manifest] to [mediadepot/coreos-manifest](https://github.com/mediadepot/coreos-manifest) and then ran
`git clone git@github.com:mediadepot/coreos-manifest.git`

You may have noticed that there's a ton of branches in this repo. These branches are all prefixed with `build-`. These `build-` branches
are how CoreOS manages versioning and directly matches the major version specified in https://coreos.com/releases/

![build branches]({{ site.url }}/assets/images/coreos/build_branches.png]

In my case I want to build my custom image off of the current CoreOS Stable version which is `1911.4.0`.

To do this, I'll checkout the `build-1911` branch, and then create a new branch ontop of that:

```
git checkout build-1911
git checkout -b mediadepot
git commit --allow-empty -m "Mediadepot branch created from build-1911"
git push
```

Now you'll have a branch built off the latest stable release that's ready to work with.

After looking at the various repos mentioned in the `master.xml` you may have noticed a repository called `coreos/coreos-overlay`.
The `coreos-overlay` repo contains Container Linux specific packages and Gentoo packages that differ from their upstream Gentoo versions.
This is also where the CoreOS kernel customizations are contained.

We'll fork this repo, following the same procedure we followed with `coreos/manifest`

```
git clone git@github.com:mediadepot/coreos-overlay.git
git checkout build-1911
git checkout -b mediadepot
git commit --allow-empty -m "Mediadepot branch created from build-1911"
git push
```

The file containing the kernel config options can be found in
[sys-kernel/coreos-modules/files/amd64_defconfig-4.14](https://github.com/mediadepot/coreos-overlay/blob/mediadepot/sys-kernel/coreos-modules/files/amd64_defconfig-4.14)

# Kernel Config Options

Now that we've determined which file we need to modify, we need to determine the kernel options that we need to enable.

Once again we go back to the `coreos_developer_container` that we used in [Customize CoreOS Kernel - Part 1](https://blog.thesparktree.com/customize-coreos-kernel-part-1#configure-kernel-options)

We'll run `make menuconfig` in the `usr/src/linux` directory to select all our kernel options, follow the remaining steps in the previous post,
 and then we'll run a new command: `scripts/diffconfig .config.old .config`

The output from this command is basically a diff listing all the changes necessary to enable your selected kernel customizations from the base CoreOS kernel.

We'll need to massage the output a bit by removing `+` characters, transitions and prefixing each line with `CONFIG_`. We'll end up with something like this:


```
CONFIG_AGP=y
CONFIG_BACKLIGHT_CLASS_DEVICE=m
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_DRM=m
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_SYS_IMAGEBLIT=y
CONFIG_I2C=y
CONFIG_I2C_ALGOBIT=y
CONFIG_LOGO=y
CONFIG_REGMAP_I2C=y
CONFIG_RTC_I2C_AND_SPI=y
CONFIG_SYNC_FILE=y
CONFIG_ACPI_I2C_OPREGION=y
CONFIG_ACPI_VIDEO=m
CONFIG_BACKLIGHT_GENERIC=m
CONFIG_DRM_BRIDGE=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
CONFIG_DRM_I915=m
CONFIG_DRM_I915_CAPTURE_ERROR=y
CONFIG_DRM_I915_COMPRESS_ERROR=y
CONFIG_DRM_I915_USERPTR=y
CONFIG_DRM_KMS_FB_HELPER=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_MIPI_DSI=y
CONFIG_DRM_PANEL=y
CONFIG_DRM_PANEL_BRIDGE=y
CONFIG_HDMI=y
CONFIG_INTEL_GTT=m
CONFIG_INTERVAL_TREE=y
CONFIG_LOGO_LINUX_CLUT224=y
CONFIG_LOGO_LINUX_MONO=y
CONFIG_LOGO_LINUX_VGA16=y
```

We can now paste this content at the bottom of our `sys-kernel/coreos-modules/files/amd64_defconfig-4.14` file and commit
the change to our branch.


# Build Custom CoreOS Image

Now that we've made our changes, its time to tell `cork` about our forked repositories.

Before we do anything else, lets take a snapshot of the VM. We don't want to spend another 4 hours downloading dependencies.

```bash
## HOST ##
vagrant snapshot save build_image_complete

```

Now that we've saved the state, lets `ssh` into the VM and re-configure cork to use our repository.

```bash
## HOST ##
vagrant ssh


## VM ##

cd  ~/coreos-sdk
cork update --manifest-url=https://github.com/mediadepot/coreos-manifest.git --manifest-branch=mediadepot --downgrade-replace

./set_shared_user_password.sh 12345
./setup_board --board 'amd64-usr'
./build_packages --board 'amd64-usr'

```

Note the `--board 'amd64-usr'` options specified withe
