---
layout: post
title: 'Ultimate Media Server Build - Part 1 - Hardware'
date: '19-01-06T01:19:33-08:00'
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
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

I've referenced my home server many times, but I never had the time to go into the details of how it was built or how it works.
Recently I decided to completely rebuild it, replacing the hardware and basing it on-top of a completely new operating system.
I thought it would be a good idea to keep a build log, tracking what I did, my design decisions, and constraints you should consider
if you want to follow in my footsteps.

This series will be broken up into multiple parts

- **Part 1 - Hardware**
- Part 2 - Build Log
- Part 3 - MediaDepot/CoreOS Configuration
- Part 4 - Application Docker Containers

This is **Part 1**, where we'll be talking about the Hardware. Specifically the hardware I chose to build my server, the
alternatives I explored and compromised I had to consider.

---

# Hardware

Since most of you just care about the part list and the price, lets get that out of the way first:

Type|Item|Price
:----|:----|:----
**CPU** | [Intel - Xeon E3-1275 V6 3.8 GHz Quad-Core Processor](https://amzn.to/2snR6Bd) | $367.97 
**CPU Cooler** | [Noctua - NH-L9i 33.84 CFM CPU Cooler](https://amzn.to/2Md8P7z) | $39.95 
**Motherboard** | [Supermicro - X11SSL-CF Micro ATX LGA1151 Motherboard](https://amzn.to/2RPHNs8) | $275.00
**Memory** | [Crucial - 32 GB (2 x 16 GB) DDR4-2400 Memory](https://pcpartpicker.com/product/LXDzK8/crucial-32gb-2-x-16gb-ddr4-2400-memory-ct9029050) | $380.00
**Power** | [Seasonic SS-350M1U Seasonic Power Supply SS-350M1U EPS 1U ATX12V v23.1 & EPS12V 80PLUS 350W Brown Box](https://pcpartpicker.com/product/xTjWGX/seasonic-ss-350m1u-seasonic-power-supply-ss-350m1u-eps-1u-atx12v-v231-eps12v-80plus-350w-brown-box) | $80.00
**Case**| [U-NAS NSC-810A Server Chassis](http://www.u-nas.com/xcart/product.php?productid=17640) | $245.00
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq) | $250.20
**Boot Drive** | [Samsung 500GB 860 EVO 2.5" SSD](https://amzn.to/2VW45Y7) | $82.99
**Video Card** | [PNY - Quadro P2000 5 GB Video Card](https://amzn.to/2D6dKUI) | $425.00
**Other** | [Cable Matters Internal Mini-SAS HD to 4x SATA Forward Breakout Cable 3.3 Feet](https://amzn.to/2CibYyh) | $17.99 
**Other** | [Clovertale Braided ATX Sleeved Cable Extension kit for Power Supply Cable Kit, PSU connectors, 24 Pin, 8 pin, 6 pin 4 + 4 Pin, 6 Pack, with Reusable Fastening Cable Ties 10 Pack (Red/Black)](https://amzn.to/2D63ITt) | $26.99
**Other** | [EMOZNY Dupont Wire Kit Male to Male,Femaleto Female, Male to Female, Pin Headers, Jumper Caps Kit (Standard)](https://amzn.to/2VLMX7n) | $9.98
 | **Total** | **$3421.22**


Yeah, you read that right, ~3k for my ultimate media server, and thats using server grade hardware thats already 2 years old. This is an expensive hobby.

Let's break it down and discuss each item, and why it was chosen over the alternatives.

## Case
Though its not traditionally important, in a home server the case you choose sets a lot more limitations than a traditional pc or even a rack mounted server.

In my case, I wanted the following:

- support for at-least 8 hot-swappable hard drives
- room for a dedicated SSD boot disk
- adequate ventilation for a micro-ATX (or a mini-ITX) motherboard
- look more like an appliance than a computer tower
- have the smallest footprint possible.

I decided to go with the [NSC-810A by U-NAS](http://www.u-nas.com/xcart/product.php?productid=17640). It's a bit on the expensive side when it comes to a case, but it provides me with the room to use a
micro-ATX motherboard, while still supporting 8 hot-swappable hard drives in a small footprint. And it doesn't look that bad either,
which is important for a server that's sitting on my shelf, rather than a server rack in the basement.

![nsc-810a]({{ site.url }}/assets/images/nas/unas-nsc-810A.jpg)

| Specification | Value |
| --- | --- |
| Model Number | NSC-810A |
| Hot Swap Drive Bays | 8x 3.5" |
| Internal Drive Bays | 1x 2.5" |
| Motherboard | Micro ATX |
| PCIe Slots | 2x |
| Power Supply Form Factor | 1U Flex |
| Dimensions(L x W x H) | 31.5cm x 27.5cm x 19.7cm |
[source](http://www.u-nas.com/xcart/product.php?productid=17640)

### Compromises

- Cable extensions are required for PSU
- Cable extensions are required for Front-Panel headers
- Riser cables/cards are required for PCIe expansion cards


## CPU

When choosing a CPU, there's a few requirements I had to consider

- My server would be running 24x7 so the CPU should be fairly efficient
- There would be lots of applications running at the same time, so a high core count would be preferable.
- A higher clock speed would ensure that video transcodes would complete faster
    - My plan includes a dedicated video card for hardware transcodes, so this does not apply
- Uptime and stability are almost more important than raw performance, so ECC memory would be preferred.
- I want a modern (but cost effective) CPU that will be able to handle my workload for years

Here's a helpful table I put together so I could quickly compare CPU's as they are referenced in different ways.

| Generation | Year | Xeon Family Number | Core Family Name | Socket |
| --- | --- | --- | --- | --- |
| 3 | 2012 | v2 | Ivy Bridge | 1155/H2 |
| 4 | 2013 | V3 | Haswell | 1150, 2011-1 |
| 5 | 2015-Jun | v4 | Broadwell | 1150, 2011 |
| 6 | 2015-Sept | v5 | Skylake | 1151, 2066 |
| 7 | 2017-Jan | V6 | Kaby Lake | 1151, 2066 | 
| 8 | 2017-Oct	| | Coffee Lake	| |

Given these requirements I decided to go with a Xeon V6 processor. Specifically the [Xeon E3-1275V6](https://amzn.to/2snR6Bd).

You might think that the Xeon [Xeon E3-1275V6](https://amzn.to/2snR6Bd) is probably overkill for a simple NAS, and you're not wrong.
The reason I chose is is that my server is not a simple NAS, it'll be running a bunch of applications in parallel 24x7 and I
wanted the highest multi-core and CPU clock I could get without breaking the bank.

If you're not going to be running as many workloads on your home server as I am feel free to dial back the power (and cost) of your CPU. **However I would stay away from the E3-1220V6 or below as it only has 2 cores vs 4 cores for E3-1230V6 and above**

![xeon e3-1275V6]({{ site.url }}/assets/images/nas/xeon-e3-1275V6.jpg)

| Specification | Value |
| --- | --- |
| Code Name | Kaby Lake |
| Processor Number | E3-1275V6 | 
| Launch Date | Q1'17 |
| Cores | 4 |
| Threads | 8 |
| Base Clock | 3.80 GHz |
| Max Clock | 4.20 GHz |
| TDP | 73 W |
| Socket | LGA1151 |
| Max RAM | 64GB |

[source](https://ark.intel.com/products/97478/Intel-Xeon-Processor-E3-1275-v6-8M-Cache-3-80-GHz-)

### Compromises

You'll want to consider the applications you're running on your server:

- The rule of thumb for ZFS is 1GB RAM for every 1TB of storage. 
	- With 8 storage drives you could potentially have 96TB of storage (8*12TB) which is more than the Max RAM.
- Socket 1151 has been replaced by Socket 2066, so if you want to eventually upgrade to a newer CPU, you wont be able to.  


## CPU Fan

Given that we've selected a small form factor case and a powerful CPU, ventilation and cooling are going to become very important.
Noctura is well known in the PC market for their quiet but powerful cooling solutions.
They have a CPU fan thats targeted specifically towards small form factor cases, and is compatible with our LGA1151 CPU socket:
[Noctua - NH-L9i](https://amzn.to/2Md8P7z)

Thats not enough though. We'll need to verify that the Thermal Design Power (TDP) of our chosen CPU is compatible with the Noctura fan.

> The thermal design power (TDP), sometimes called thermal design point, is the maximum amount of heat generated by a computer chip or component (often a CPU, GPU or system on a chip) that the cooling system in a computer is designed to dissipate under any workload.
> https://en.wikipedia.org/wiki/Thermal_design_power

Thankfully Noctura releases TDP guidelines for all their fans, including the [NH-L9i](https://noctua.at/en/nh_l9i_tdp_guidelines). Though our exact CPU model is not listed as compatible, we can see that the fan can handle ~91W TDP from Kaby Lake processors, which higher than our expected TDP of 71W.

![noctua nh-l9i]({{ site.url }}/assets/images/nas/noctua-nh-l9i.jpg)

## Motherboard

Now that we've chosen our Case and CPU, it's time to find a compatible motherboard. 
Given the size constraints of our case and socket constraints of our CPU, we're looking for something that matches the following requirements:

 - Socket LGA1151 compatible, specifically the Xeon V6 family.
 - Micro-ATX
 - Can support 9+ SATA drives (8 storage drives + 1 OS drive)
 - At least one 16x PCIe slot (we want to use a dedicated video card for transcoding, see [Video Card](#video-card))
 - Support for 64GB of RAM
 - Remote management capability (low priority)

For "enthusiast" server grade hardware, theres a couple of trusted names:

- Supermicro
- ASRock Rack
- ASUS

I ended up focusing on Supermicro as I was able to find a broader range of server motherboards.

If you're looking at Supermicro motherboards I highly recommend the following resources: 

- [Supermicro Motherboard Matrix](https://www.supermicro.com/support/resources/MB_matrix.php) - compare/filter all Supermicro motherboards
- [Supermicro Product Naming Conventions](https://www.supermicro.com/products/Product_Naming_Convention/Naming_MBD_Intel_UP.cfm) - helped me decode the motherboard feature just by glancing at model numbers
 
After comparing features and looking at prices, I settled on the [X11SSL-CF motherboard by Supermicro](https://amzn.to/2RPHNs8).

Before we dive into why, lets take a look at some other motherboards I considered, but ultimately decided against:

| Model | Cost (USD) | Issue(s) |
| --- | --- | --- |
| [X11SSZ-TLN4F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSZ-TLN4F.cfm) | $357.41 | Not enough SATA/No SAS expansion |
| [X11SSZ-F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSZ-F.cfm) | $230.72 | Not enough SATA/No SAS expansion |
| [X11SSM-F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSM-F.cfm) | $197 | Not enough SATA/No SAS expansion |
| [X11SSL-F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSL-F.cfm) | $197 | Not enough SATA/No SAS expansion |
| [X11SSi-LN4F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSi-LN4F.cfm) | $229.69 | Not enough SATA/No SAS expansion |
| [X11SSH-LN4F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSH-LN4F.cfm) | $227.63 | Not enough SATA/No SAS expansion |
| [X11SSH-F](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSH-F.cfm) | $213.21 |  Not enough SATA/No SAS expansion |
| [X11SSH-CTF](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSH-CTF.cfm) | $408 | No x16 PCIe slot, expensive |

My 2 reasons for filtering out motherboards were:

- Not enough SATA/No SAS expansion (solvable via [HBA controller card](https://www.amazon.com/SAS9211-8I-8PORT-Int-Sata-Pcie/dp/B002RL8I7M) but loses PCIe slot)
- No x16 PCIe slot (solvable via [powered 8x-16x PCIE riser card](https://www.moddiy.com/products/PCI%252dExpress-PCI%252dE-16X-to-16X-Riser-Card-Flexible-Ribbon-Extender-Cable-w%7B47%7DMolex-%252b-Solid-Capacitor.html) but I'm uncomfortable with the power supply)

While there are solutions for each of the problems above I went with a no-compromises motherboard that gave me everything I wanted out of the box. 

| Specification | Value |
| --- | --- |
| Model Number | [X11SSL-CF](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSL-CF.cfm) |
| Socket | LGA1151 |
| Processor Support | Xeon E3-1200 v6/v5 or 7th/6th Gen. Core i3 |
| Chipset | C232 | 
| RAM Slots | 4 DIMM |
| RAM Type | Unbuffered ECC UDIMM DDR4 2400MHz |
| RAM Max | 64GB |
| PCIe Slots | 1 PCI-E 3.0 x8 (in x16),  1 PCI-E 3.0 x4 (in x8),1 PCI-E 3.0 x1 |
| SAS | 2x mini-SAS HD (SFF8643) SAS3 |
| Remote Management | [IPMI](https://www.supermicro.com/en/solutions/management-software/bmc-resources) |

![supermicro x11ssl-cf]({{ site.url }}/assets/images/nas/supermicro-x11ssl-cf.jpg)


### Compromises 

While this motherboard works great for my requirements, you should pay attention to the following compromises:

- The Chipset is C232, which does not support Intel iGPU/onboard Video 
	- C236 is focused for desktop use and supports Intel iGPU
- DDR4 ECC UDIMM is expensive and hard to find 
- Supermicro motherboards are notorious for RAM incompatibility (here's the [official compatibility list](https://www.supermicro.com/support/resources/memory/display.cfm?mspd=2.4&mtyp=95&id=5E439CF38EB300CF19AD9C0E862DCBF9&prid=84936&type=DDR4%201.2V&ecc=1&reg=0&fbd=0))
- v1.x of the BIOS does not work with Xeon V6 CPU's, you need to upgrade to v2.x
	- boot using a Xeon v5 and then flash the BIOS
	- RMA the board and get the manufacturer to update the BIOS
	- buy a license for IPMI (~$20) and update the BIOS using the management console.
- 1Gigabit Ethernet (not 10Gigabit Ethernet)
- Supermicro motherboards with an onboard SAS controller is more expensive, look at LSI HBA controller cards if you have room.


# Memory (RAM)
Our options for RAM are limited by our motherboard and CPU:

- 64GB max
- 16GB max per DIMM slot
- 4 DIMM slots
- must be DDR4
- must be ECC
- must be Unbuffered 
- *should* be on the [official compatibility list](https://www.supermicro.com/support/resources/memory/display.cfm?mspd=2.4&mtyp=95&id=5E439CF38EB300CF19AD9C0E862DCBF9&prid=84936&type=DDR4%201.2V&ecc=1&reg=0&fbd=0)
- must not cost and arm and a leg

When it comes to ECC UDIMM DDR4 RAM, its that last point that's the problem. DDR4 RAM is expensive, and RAM for our chosen motherboard/cpu even more so. 

I ended up going with Crucial RAM that was compatible on paper, even though it wasn't on the official compatibility list because I wanted to save money and it had been tested working on the same model motherboard. 

## Power Supply (PSU)

We're looking for a PSU that is:

- 1U Flex form factor
- 300-350W 
	- 8*10W per disk
	- Video Card
	- 65-250W Motherboard/CPU
- Modular if possible (saves space)
- [80 PLUS Certified](https://www.tomshardware.com/reviews/psu-buying-guide,2916-5.html) - Power efficient since we're running 24x7
- Quiet (server PSU's are known to be jet-engine loud)

The only real PSU that matches these requirements is the Seasonic SS-300M1U and Seasonic SS-350M1U. I decided to go with the [SS-350M1U](https://pcpartpicker.com/product/xTjWGX/seasonic-ss-350m1u-seasonic-power-supply-ss-350m1u-eps-1u-atx12v-v231-eps12v-80plus-350w-brown-box) as I felt the extra power was necessary with my dedicated video card. With just storage drives you may be fine with just the SS-300M1U.

| Specification | Value |
| --- | --- |
| Model | Seasonic SS-350M1U |
| Wattage | 350W |
| Efficiency | 80 PLUS |
| Cabling | Modular |
[source](http://www2.seasonic.com/product/ss-350-m1u-active-pfc-f0/)

![seasonic SS-350M1U]({{ site.url }}/assets/images/nas/seasonic-SS-350M1U.png)

### Compromises

- It seems that the SS-300M1U and SS-350M1U PSU's are end-of-life and are no longer manufactured. Unfortunately I was unable to find a replacement, so I purchased mine used on Ebay.
- It does not have an 8-pin power connector, only a 4-pin. That was seemingly ok with my motherboard, but YMMV.

## Video Card
While a video card is optional for most servers, I'm building a dedicated streaming/transcoding server for Plex and the iGPU just isn't enough. 

I need a video card that:

- can handle a large number of simultaneous transcodes
- supports a large number of codecs
- only takes up 1 PCIe slot
- doesn't have significant power requirements
- can handle heavy, long duration usage
- can fit in a small form factor case

Again, there wasn't much to choose from. The [Nvidia Quadro P2000](https://amzn.to/2D6dKUI)  (released 2017) is the first enterprise video card that supports [unlimited concurrent transcodes](https://developer.nvidia.com/video-encode-decode-gpu-support-matrix). Later versions of the video card add additional features while costing significantly more. It's the best cost-effective solution for a transcode heavy server like mine.

| Specification | Value |
| --- | --- |
| Model | Nvidia Quadro P2000 |
| GPU Memory | 5GB | 
| Interface | PCIe x16 | 
| Transcodes | Unlimited |
| Max Power Consumption | 75W |
| Form Factor | 4.40" H x 7.90" L, Single Slot |
[source](https://www.pny.com/nvidia-quadro-p2000)

![nvidia quadro p2000]({{ site.url }}/assets/images/nas/nvidia-quadro-p2000.jpeg)

### Compromises

- requires a PCIe x16 slot (uncommon in micro-ATX motherboards)
- additional power consumption
- iGPU is more cost effective for infrequent transcoding usage

## Boot Drive

Here's what I considered when choosing my boot drive:

- a 2.5" drive that mounts in the NSC-810A boot drive bay
- has fast I/O as I'll be running multiple docker containers & applications on my server concurrently
- should be atleast 300GB large, as the boot drive will act like a cache drive for all my applications (some of which are media heavy like Plex) and will be the primary drive for new downloads (until the downloads are complete and moved to a storage drive automatically)
- S.M.A.R.T capable so that I can monitor the health of the drive using automated tools. 
- Low power usage 
 
I ended up going with a  [Samsung 500GB 860 EVO 2.5" SSD](https://amzn.to/2VW45Y7) drive as it checked off all of the boxes. 

| Specification | Value |
| --- | --- |
| Model | Samsung 500GB 860 EVO |
| Capacity | 500GB | 
| Form Factor | 2.5" | 
| Max Seq Read | Up to 550 MB/s |
| Max Seq Write | Up to 520 MB/s	 |
| NAND Type | Samsung 64-Layer V-NAND |
| S.M.A.R.T. Support | Yes |
| Max Power Consumption | 4.0W |
[source](https://www.samsung.com/us/computing/memory-storage/solid-state-drives/ssd-860-evo-2-5--sata-iii-500gb-mz-76e500b-am/)

![samsung 860 evo]({{ site.url }}/assets/images/nas/samsung-500gb-evo-860.jpg)


### Compromises
- The Samsung 860 EVO is a TLC NAND type drive:

	> Storing 3 bits per cell, TLC flash is the cheapest form of flash to manufacture. The biggest disadvantage to this type of flash is that it is only suitable for consumer usage, and would not be able to meet the standards for industrial use. Read/write life cycles are considerably shorter at 3,000 to 5,000 cycles per cell.	 
	[SLC, MLC, TLC](https://www.mydigitaldiscount.com/everything-you-need-to-know-about-slc-mlc-and-tlc-nand-flash.html)

While this concerning, I've mitigated the issue with the following:
- The boot drive contains very little important data, all completed downloads and persistent data is automatically moved off onto the storage drives
- Application data is backed up into the cloud using `duplicati`.
- S.M.A.R.T will notify me when my drive begins to fail
- The drive is incredibly cheap for the performance it provides. 


## Storage

Storage one of the most important areas of our built, but its also one of the most flexible. 
Our server is designed to use JBOD (Just-a-bunch-of-disks) meaning we can add storage as necessary, and our disks can be of varying sizes (unlike RAID).

However, even with this flexibility, there are a couple of things we're looking for:

- S.M.A.R.T support to ensure that we can monitor the health of our drives
- Read speed performance
- Good price to GB ratio
- NAS type storage drives, power efficient
- Large cache 

I went with the [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://amzn.to/2SNujdq). 

| Specification | Value |
| --- | --- |
| Model | Western Digital - Red |
| Capacity | 8TB | 
| Cache | 256MB | 
| RPM | 5400 |
| S.M.A.R.T. Support | Yes |
[source](https://www.wd.com/products/internal-storage/wd-red.html)

![wd nas red]({{ site.url }}/assets/images/nas/wd-nas-red-8tb.jpg)


### Compromises
- You can also [shuck white label versions of this drive from EasyStore 8TB](https://imgur.com/gallery/IsZxx)
