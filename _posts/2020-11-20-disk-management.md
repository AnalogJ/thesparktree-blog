---
layout: post
title: 'Home Server - Disk Management'
date: '20-11-20T01:19:33-08:00'
cover: '/assets/images/cover_plex.jpg'
subclass: 'post tag-post'
tags:
- homeserver
- plex
- hardware
- linux
- supermicro
- nas

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

# Adding a new disk to your homeserver

## Identify your new devices

1. Take photos of your drives before inserting them. Specifically, you'll want to track the serial number, manufacturer and model.
This will make identifying the new drives in a large system much easier.
2. Install the drives and power on your server.
3. Get a list of your mounted drives using `cat /etc/mtab | grep /dev/`.
If you use specific drive mounting folder structure, you can be fairly certain these devices do not correspond with your newly added drives.

```
/dev/sdg /mnt/drive4 ext4 rw,seclabel,relatime 0 0
/dev/sdb /mnt/drive5 ext4 rw,seclabel,relatime 0 0
/dev/sdf /mnt/drive1 ext4 rw,seclabel,relatime 0 0
/dev/sdd /mnt/drive2 ext4 rw,seclabel,relatime 0 0
```

4. List all device detected by your system, and ignore references to devices that you already recognize.
```
$ ls -alt /dev/sd*
brw-rw----. 1 root disk 8, 32 Nov 21 16:40 /dev/sdc
brw-rw----. 1 root disk 8, 64 Nov 21 16:23 /dev/sde
brw-rw----. 1 root disk 8,  1 Nov 21 16:01 /dev/sda1
brw-rw----. 1 root disk 8,  2 Nov 21 16:01 /dev/sda2
brw-rw----. 1 root disk 8,  0 Nov 21 16:01 /dev/sda
brw-rw----. 1 root disk 8, 16 Nov 21 16:01 /dev/sdb
brw-rw----. 1 root disk 8, 80 Nov 21 16:01 /dev/sdf
brw-rw----. 1 root disk 8, 96 Nov 21 16:01 /dev/sdg
brw-rw----. 1 root disk 8, 48 Nov 21 16:01 /dev/sdd
```
In this case, all we care about are `/dev/sdc` and /dev/sde`

5. Get information about these unknown devices, to match against the Manufacturer, Model & Serial number of the inserted drives.


```
$ fdisk -l

...

Disk /dev/sde: 12.8 TiB, 14000519643136 bytes, 27344764928 sectors
Disk model: WDC WD140EDFZ-11
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes

Disk /dev/sdc: 12.8 TiB, 14000519643136 bytes, 27344764928 sectors
Disk model: WDC WD140EDFZ-11
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
```

The models listed match our disk models, but lets get their serial numbers to be sure.

```
$ udevadm info --query=all --name=/dev/sdc | grep SERIAL
E: ID_SERIAL_SHORT=Y5HXXXXX

$ udevadm info --query=all --name=/dev/sde | grep SERIAL
E: ID_SERIAL_SHORT=9LGXXXXXX
```
Once we've confirmed these serial numbers match the devices we added, it's time to format the devices.

## Format

We'll be using [trapexit's excellent backup & recovery guide](https://github.com/trapexit/backup-and-recovery-howtos) as a reference here.

```
$ mkfs.ext4 -m 0 -T largefile4 -L <label> /dev/<device>

mke2fs 1.42.9 (4-Feb-2014)
Discarding device blocks: done
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
16 inodes, 4096 blocks
0 blocks (0.00%) reserved for the super user
First data block=0
1 block group
32768 blocks per group, 32768 fragments per group
16 inodes per group

Allocating group tables: done
Writing inode tables: done
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done
```

* -m <reserved-blocks-percentage>: Reserved blocks for super-user. We set it to zero because these drives aren't used in a way where that really matters.a
* -T <usage-type>: Specifies how the filesystem is going to be used so optimal paramters can be chosen. Types are defined in `/etc/mke2fs.conf`. We set it to `largefile4` because we expect fewer, large files relative to typical usage. If you expect a large number of files or are unsure simply remove the option all together.
* -L <label>: Sets the label for the filesystem. A suggested format is: SIZE-MANUFACTURE-N. For example: `2.0TB-Seagate-0` for the first 2.0TB Seagate drive installed.

It's generally a good idea to format the raw device rather than creating partitions.

1. The partition is mostly useless to us since we plan on using the entire drive for storage.
2. We won't need to worry about MBR vs GPT.
3. We won't need to worry about block alignment which can effect performance if misaligned.
4. When a 512e/4k drive is moved between a native SATA controller and a USB SATA adaptor there won't be partition block misalignment. Often USB adapters will report 4k/4k to the OS while the drive will report 512/4k causing the OS to fail to find the paritions or filesystems. This can be fixed but no tools exist to do the procedure automatically.


## Mount
Next we'll need to mount the devices.

Lets make the mount directories, following our folder naming structure.

```
mkdir -p /mnt/drive3
mkdir -p /mnt/drive6
```
Next we can actually mount the devices the new directories

```
mount /dev/sde /mnt/drive3
mount /dev/sdc /mnt/drive6
```

These mounts are just for testing, and are not persistent. Since we're using Systemd, we can create mount config files
and tell Systemd to automatically mount our drives and manage them.

```
systemctl edit --force --full mnt-drive3.mount

[Mount]
What=/dev/disk/by-uuid/e1378723-7861-49b9-8e01-0bd063f0ecdd
Where=/mnt/drive3
Type=ext4

[Install]
WantedBy=local-fs.target
```

Finally  we need to "enable" the systemd service:

`systemctl enable mnt-drive3.mount`

