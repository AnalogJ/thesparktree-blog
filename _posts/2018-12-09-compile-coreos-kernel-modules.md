---
layout: post
title: 'Compile CoreOS Kernel Modules - Part 1'
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

# Story Time

As a Devops & Infrastructure guy, I'm pretty comfortable with jumping into the unknown, be it infrastructure, architecture or application code.
With a bit of help from Google I can usually come up with a working solution, even if the end result needs a bit of polish afterwards.

That self-assurance was checked on my latest project: **building a dockerized home server.**

I've touched on my home server a bit in the past, and I'll be doing a follow up post on it later, but here's a quick summary of what it does:

- Its a home server, so it needed to be physically small and quiet, but easy to upgrade.
- Storage space was more important than content archival, so a JBOD disk array was required
- All applications should run in Docker where possible, for ease of installation, minimizing conflicts and updating.
- **OS needed to be as minimal as possible, since all work was done in Docker containers**

I've had a Home Server that checked off the first three items for a while, but not that last one. Professionally, I've been lucky enough to
use (and abuse) a Kubernetes cluster which builds our Jenkins jobs. That Kubernetes cluster was built ontop of ~CoreOS~ Container Linux, which
I've grown to love. It checks off that last requirement perfectly.

So I did what any tinkerer would do, I started up a CoreOS VM, rebuilt my entire software stack for another OS, learned a compeletely new
configuration management tool ([Ignition](https://github.com/mediadepot/ignition) is pretty slick), and finally wiped my server's OS and installed CoreOS
& my dockerized applications.

This is where our story actually begins, which will eventually lead me down a rabbit hole of device drivers & kernel modules.

**The `/dev/dri` folder was missing on CoreOS.**

I eventually got around to starting up Plex on my homeserver, and while everything looked fine, I noticed that the container was not automatically doing Hardware Transcoding
for video, like it should be.
After doing a bunch of debugging I determined that I needed to compile the CoreOS Kernel with a couple of extra options enabled:

- `Direct Rendering Manager (XFree86 4.1.0 and higher DRI support)`
- `Intel 8xx/9xx/G3x/G4x/HD Graphics`

Here's the first problem. If you're unfamiliar with CoreOS, all you need to know is that unlike traditional OS's the CoreOS kernel is
continuously updated, similar to how Google Chrome is always kept up-to date. This means that **any local modifications I make to the kernel
will be completely lost on the next kernel update**.

Thankfully kernel developers have provided a way to load code into the kernel, without recompiling the whole thing: kernel modules.

# Compiling CoreOS Kernel Modules (In-Tree or Out-Of-Tree)
Here's where we end story time and actually start coding.

CoreOS is so minimal that it doesn't even have a any compilers or even a package manager installed.
In fact, it's designed such that all real work takes place inside of containers.

But before we can even do much work towards solving problem 1, we run into a second issue: **the standard location for storing kernel modules `/lib/modules` is read-only in CoreOS.**
If you think about it, it kind of all makes sense: an OS that auto-updates its kernel needs to ensure that it controls all locations where
kernel code is loaded from.

We'll solve problem 2 first, by creating a `overlay` filesystem over the standard `/lib/modules` directory. This overlay filesystem will
leave the underlying directory untouched, while creating a new writable directory where we can place our kernel modules.

```bash
## HOST ##

modules=/opt/modules  # Adjust this writable storage location as needed.
sudo mkdir -p "$modules" "$modules.wd"
sudo mount \
    -o "lowerdir=/lib/modules,upperdir=$modules,workdir=$modules.wd" \
    -t overlay overlay /lib/modules
```

Next we'll add an entry to `/etc/fstab` to ensure that we automatically mount the overlay when the system boots

```bash
## HOST ##

$ cat /etc/fstab

overlay /lib/modules overlay lowerdir=/lib/modules,upperdir=/opt/modules,workdir=/opt/modules.wd,nofail 0 0

```

Now that problem #2 is solved, lets go back to problem #1: the lack of a package manager and compilation tools in CoreOS.
Thankfully the CoreOS developers provide a `develoment container`, which has a bunch of tools that can be used to manipulate CoreOS (and includes a package manager).

```bash
## HOST ##

# change to a well known location, with enough space for atleast a 3GB image
cd ~


# read system configuration files to determine the URL of the development container that corresponds to the current Container Linux version

. /usr/share/coreos/release
. /usr/share/coreos/update.conf
url="http://${GROUP:-stable}.release.core-os.net/$COREOS_RELEASE_BOARD/$COREOS_RELEASE_VERSION/coreos_developer_container.bin.bz2"

# Download, decompress, and verify the development container image.

gpg2 --recv-keys 04127D0BFABEC8871FFB2CCE50E0885593D2DCB4  # Fetch the buildbot key if neccesary.
curl -L "$url" |
    tee >(bzip2 -d > coreos_developer_container.bin) |
    gpg2 --verify <(curl -Ls "$url.sig") -

```
Now that we've downloaded the developement container image (`coreos_developer_container.bin`) we can create a container based off of it.
Problem 3 rears its ugly head now: **containers created via `systemd-nspawn` seem to have a diskspace limit of ~3GB.** This can be fixed by
doing a couple of additional volume mounts when starting the container:

```bash
## HOST ##

cd ~
mkdir boot src

sudo systemd-nspawn \
--bind=/tmp \
--bind="$PWD/boot:/boot" \
--bind=/lib/modules:/lib/modules \
--bind="$PWD/src:/usr/src" \
--image=coreos_developer_container.bin
```

## Inside CoreOS Development Container

Now that we're inside the development container, we'll update the package manager and download the coreos kernel source

```bash
## DEVELOPMENT CONTAINER ##

emerge-gitclone
emerge -gKv bootengine coreos-sources dracut
update-bootengine -o /usr/src/linux/bootengine.cpio

```

## Configure Kernel Options
The kernel source for the current kernel will be downloaded to the following path `/usr/src/linux-$(uname -r)` and symlinked to `/usr/src/linux`.
Lets configure the kernel options to enable the I915 driver (and it's dependencies) to be built as a kernel module.

```bash
## DEVELOPMENT CONTAINER ##

cd /usr/src/linux  # remember, this is a symlink to your exact kernel source code

# lets ensure we're working from a clean copy of the source tree.
make distclean

# lets copy over the symbols file for the current kernel
cp /lib/modules/`uname -r`/build/Module.symvers .

# lets copy over the .config used to build the current kernel
gzip -cd /proc/config.gz > /usr/src/linux/.config

# lets backup the current config
make oldconfig

# lets use the interactive UI to enable the options that we need to enable.
# remember, "m" means build as module.
make menuconfig

# next lets prepare the source code to be built
make prepare && make modules_prepare
make -C /usr/src/linux scripts

# (OPTIONAL) finally, lets validate that the options we need are enabled.
cat .config | grep DRM
diff .config.old .config

```

## Build & Install Kernel Module(s)

Initially all I did here was build the one module I thought was necessary: `/drivers/drm`, but after taking a closer look
at the output of `diff .config.old .config` it's clear that a couple of other kernel options were enabled as well, and their modules are dependencies for
the `Intel i915 driver` to work correctly.

The general form for building and installing a kernel module looks like the following:

```bash
## DEVELOPMENT CONTAINER ###
make -C /usr/src/linux SUBDIRS=drivers/gpu/drm modules && make -C /usr/src/linux SUBDIRS=drivers/gpu/drm modules_install
```

However, since there's additional kernel modules that we need, the full build command looks like:

```bash
## DEVELOPMENT CONTAINER ###

make -C /usr/src/linux M=drivers/video modules && make -C /usr/src/linux M=drivers/video modules_install
make -C /usr/src/linux M=drivers/acpi KBUILD_EXTMOD=drivers/video modules && make -C /usr/src/linux M=drivers/acpi KBUILD_EXTMOD=drivers/video modules_install
make -C /usr/src/linux M=drivers/gpu/drm KBUILD_EXTMOD=drivers/acpi KBUILD_EXTMOD=drivers/video modules && make -C /usr/src/linux KBUILD_EXTMOD=drivers/acpi KBUILD_EXTMOD=drivers/video M=drivers/gpu/drm modules_install
```

The `make modules` command will build & compile the `.ko` files, while the `make modules_install` command will copy them to the `/lib/modules/$(uname -r)/extras/` directory.
Lets validate that the kernel modules we require are all there:

```
## DEVELOPMENT CONTAINER ##
ls -alt /lib/modules/$(uname -r)/extras/

# if everything looks good, we can exit from the container back to the host

exit

```

## Prepare Kernel Modules
So at this point we have a handful of kernel modules, but we're not quite ready to load them into the kernel yet. We need to run a tool called `depmod` first

> depmod creates a list of module dependencies by reading each module under */lib/modules/version* and determining what symbols
> it exports and what symbols it needs. By default, this list is written to *modules.dep* in the same directory. If
> filenames are given on the command line, only those modules are examined (which is rarely useful unless all modules are listed).

Lets run it on the host, to update the `modules.dep` file.

```bash
## HOST ##
depmod
```

Well that was easy.

## Load Kernel Modules

Here we are at the moment of truth, lets load our kernel modules into the kernel using `modprobe`. If we did everything right the command should complete silently for each module.

> modprobe intelligently adds or removes a module from the Linux kernel: note that for convenience, there is no difference between _ and - in module names. modprobe looks in the module directory /lib/modules/'uname -r' for all the modules and other files, except for the optional /etc/modprobe.conf configuration file and /etc/modprobe.d directory (see modprobe.conf(5)). modprobe will also use module options specified on the kernel command line in the form of <module>.<option>.

The modules in `/lib/modules/$(uname -r)/extras` should be individually loaded via `modprobe`. Note: when using modprobe, you reference kernel modules by name, not path, ie. `modprobe i915` not ~~`modprobe i915/i915.ko`~~

```bash
## HOST ##
modprobe

```


# References
- https://wiki.gentoo.org/wiki/Intel#Feature_support - Kernel options required for enabling Intel i915 driver
- https://coreos.com/os/docs/latest/kernel-modules.html - Initial instructions for building a Kernel module


