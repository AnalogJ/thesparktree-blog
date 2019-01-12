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

- Part 1 - Hardware
- Part 2 - Build Log
- Part 3 - MediaDepot/CoreOS Configuration
- Part 4 - Application Docker Containers

This is Part 1, where we'll be talking about the Hardware. Specifically the hardware I chose to build my server, the
alternatives I explored and compromised I had to consider.

---

# Hardware

Since most of you just care about the part list and the price, lets get that out of the way first:

[PCPartPicker part list](https://pcpartpicker.com/list/rd2mpG) / [Price breakdown by merchant](https://pcpartpicker.com/list/rd2mpG/by_merchant/)

Type|Item|Price
:----|:----|:----
**CPU** | [Intel - Xeon E3-1275 V6 3.8 GHz Quad-Core Processor](https://pcpartpicker.com/product/QncMnQ/intel-xeon-e3-1275-v6-38ghz-quad-core-processor-bx80677e31275v6) | $349.99 @ SuperBiiz
**CPU Cooler** | [Noctua - NH-L9i 33.84 CFM CPU Cooler](https://pcpartpicker.com/product/xxphP6/noctua-cpu-cooler-nhl9i) | $39.95 @ Amazon
**Motherboard** | [Supermicro - X11SSL-CF Micro ATX LGA1151 Motherboard](https://pcpartpicker.com/product/JxH48d/supermicro-x11ssl-cf-micro-atx-lga1151-motherboard-x11ssl-cf) | $275.00
**Memory** | [Crucial - 32 GB (2 x 16 GB) DDR4-2400 Memory](https://pcpartpicker.com/product/LXDzK8/crucial-32gb-2-x-16gb-ddr4-2400-memory-ct9029050) | $380.00
**Power** | [Seasonic SS-350M1U Seasonic Power Supply SS-350M1U EPS 1U ATX12V v23.1 & EPS12V 80PLUS 350W Brown Box](https://pcpartpicker.com/product/xTjWGX/seasonic-ss-350m1u-seasonic-power-supply-ss-350m1u-eps-1u-atx12v-v231-eps12v-80plus-350w-brown-box) | $80.00
**Case**| U-NAS NSC-810A Server Chassis| $245.00
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Storage** | [Western Digital - Red 8 TB 3.5" 5400RPM Internal Hard Drive](https://pcpartpicker.com/product/zZKcCJ/western-digital-red-8tb-35-5400rpm-internal-hard-drive-wd80efax) | $249.89 @ OutletPC
**Video Card** | [PNY - Quadro P2000 5 GB Video Card](https://pcpartpicker.com/product/x4bkcf/pny-quadro-p2000-5gb-video-card-vcqp2000-pb) | $419.99 @ B&H
**Other** | [Cable Matters Internal Mini-SAS HD to 4x SATA Forward Breakout Cable 3.3 Feet](https://www.amazon.com/Cable-Matters-Internal-SFF-8643-Breakout/dp/B01BW1U2L2) | $17.99 @ Amazon
**Other** | [Clovertale Braided ATX Sleeved Cable Extension kit for Power Supply Cable Kit, PSU connectors, 24 Pin, 8 pin, 6 pin 4 + 4 Pin, 6 Pack, with Reusable Fastening Cable Ties 10 Pack (Red/Black)](https://pcpartpicker.com/product/z8bwrH/clovertale-braided-atx-sleeved-cable-extension-kit-for-power-supply-cable-kit-psu-connectors-24-pin-8-pin-6-pin-4-4-pin-6-pack-with-reusable-fastening-cable-ties-10-pack-redblack) | $26.99 @ Amazon
**Other** | [EMOZNY Dupont Wire Kit Male to Male,Femaleto Female, Male to Female, Pin Headers, Jumper Caps Kit (Standard)](https://pcpartpicker.com/product/JPrmP6/emozny-dupont-wire-kit-male-to-malefemaleto-female-male-to-female-pin-headers-jumper-caps-kit-standard) | $9.98 @ Amazon
 | *Prices include shipping, taxes, rebates, and discounts* |
 | **Total** | **$3338.23**


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

I decided to go with the NSC-810A by U-NAS. It's a bit on the expensive side when it comes to a case, but it provides me with the room to use a
micro-ATX motherboard, while still supporting 8 hot-swappable hard drives in a small footprint. And it doesn't look that bad either,
which is important for a server that's sitting on my shelf, rather than a server rack in the basement.

<<IMAGE OF CASE HERE>>

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

Given these requirements I decided to go with a Xeon V6 processor. Specifically the Xeon E3-1275V6.

You might think that the Xeon E3-1275V6 is probably overkill for a simple NAS, and you're not wrong.
The reason I chose is is that my server is not a simple NAS, it'll be running a bunch of applications in parallel 24x7 and I
wanted the highest multi-core and CPU clock I could get without breaking the bank.

If you're not going to be running as many workloads on your home server as I am feel free to dial back the power (and cost) of your CPU. **However I would stay away from the E3-1220V6 or below as it only has 2 cores vs 4 cores for E3-1230V6 and above**

<<IMAGE OF CPU HERE>>


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


## CPU Fan

Given that we've selected a small form factor case and a powerful CPU, ventilation and cooling are going to become very important. Noctura is well known in the PC market for their quiet but powerful cooling solutions. They have a CPU fan thats targeted specifically towards small form factor cases, and is compatible with our LGA1151 CPU socket: [NH-L9i](https://noctua.at/en/nh-l9i)

Thats not enough though. We'll need to verify that the Thermal Design Power (TDP) of our chosen CPU is compatible with the Noctura fan.

> The thermal design power (TDP), sometimes called thermal design point, is the maximum amount of heat generated by a computer chip or component (often a CPU, GPU or system on a chip) that the cooling system in a computer is designed to dissipate under any workload.
> https://en.wikipedia.org/wiki/Thermal_design_power

Thankfully Noctura releases TDP guidelines for all their fans, including the [NH-L9i](https://noctua.at/en/nh_l9i_tdp_guidelines). Though our exact CPU model is not listed as compatible, we can see that the fan can handle ~91W TDP from Kaby Lake processors, which higher than our expected TDP of 71W.

<<IMAGE OF CPU COOLER HERE>>

## Motherboard

Now that we've chosen our Case and CPU, it's time to find a compatible motherboard. 
Given the size constraints of our case and socket constraints of our CPU, we're looking for something that matches the following requirements:

 - Socket LGA1151 compatible, specifically the Xeon V6 family.
 - Micro-ATX
 - Can support 9+ SATA drives (8 storage drives + 1 OS drive)
 - At least one 16x PCIe slot (we want to use a dedicated video card for transcoding, see [Video Card](#VideoCard))
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
 
After comparing features and looking at prices, I settled on the [X11SSL-CF](https://www.supermicro.com/products/motherboard/Xeon/C236_C232/X11SSL-CF.cfm) motherboard by Supermicro.

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

<<IMAGE OF MOTHERBOARD HERE>>

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

# Power Supply (PSU)

We're looking for a PSU that is:

- 1U Flex form factor
- 300-350W 
	- 8*10W per disk
	- Video Card
	- 65-250W Motherboard/CPU
- Modular if possible (saves space)
- [80 PLUS Certified](https://www.tomshardware.com/reviews/psu-buying-guide,2916-5.html) - Power efficient since we're running 24x7
- Quiet (server PSU's are known to be jet-engine loud)

The only real PSU that matches these requirements is the Seasonic SS-300M1U and Seasonic SS-350M1U. I decided to go with the SS-350M1U as I felt the extra power was necessary with my dedicated video card. With just storage drives you may be fine with just the SS-300M1U.

| Specification | Value |
| --- | --- |
| Wattage | 350W |
| Efficiency | 80 PLUS |
| Cabling | Modular |
[source](http://www2.seasonic.com/product/ss-350-m1u-active-pfc-f0/)

<<IMAGE OF PSU HERE>>

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

Again, there wasn't much to choose from. The Nvidia P2000 (released 2017) is the first enterprise video card that supports [unlimited concurrent transcodes](https://developer.nvidia.com/video-encode-decode-gpu-support-matrix). Later versions of the video card add additional features while costing significantly more. It's the best cost-effective solution for a transcode heavy server like mine.

| Specification | Value |
| --- | --- |
| Model | P2000 |
| GPU Memory | 5GB | 
| Interface | PCIe x16 | 
| Transcodes | Unlimited |
| Max Power Consumption | 75W |
| Form Factor | 4.40” H x 7.90” L, Single Slot |
[source](https://www.pny.com/nvidia-quadro-p2000)

<<IMAGE OF VIDEO CARD>>

### Compromises

- requires a PCIe x16 slot (uncommon in micro-ATX motherboards)
- additional power consumption
- iGPU is more cost effective for infrequent transcoding usage
