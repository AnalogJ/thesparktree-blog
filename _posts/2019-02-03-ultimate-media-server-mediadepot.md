---
layout: post
title: 'Ultimate Media Server Build - Part 3 - MediaDepot/CoreOS Configuration'
date: '19-01-25T01:19:33-08:00'
cover: '/assets/images/cover_plex.jpg'
subclass: 'post tag-post'
tags:
- homeserver
- plex
- hardware
- linux
- coreos
- nas

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
hidden: true
---

I've referenced my home server many times, but I never had the time to go into the details of how it was built or how it works.
Recently I decided to completely rebuild it, replacing the hardware and basing it on-top of a completely new operating system.
I thought it would be a good idea to keep a build log, tracking what I did, my design decisions, and constraints you should consider
if you want to follow in my footsteps.

This series will be broken up into multiple parts

- [Part 1 - Hardware](/ultimate-media-server-build-hardware)
- [Part 2 - Build Log](/ultimate-media-server-build-log)
- **[Part 3 - MediaDepot/CoreOS Configuration](/ultimate-media-server-build-log)**
- Part 4 - Application Docker Containers

This is **Part 3**, where I'll be discussing the software I use to run my ultimate media server, specifically focusing on installing and
configuring CoreOS for MediaDepot.

---

The hardware and build process for the **"Ultimate Media Server"** was outlined in previous posts, but hardware is only one part of the solution. Software determines the functionality and ultimately the value of our home server. 

Before we dive into the details, let’s start with a bit of a teaser showing off some of the applications and services that I run on my server.

<blockquote class="imgur-embed-pub" lang="en" data-id="a/VMcMtVY"><a href="//imgur.com/VMcMtVY"></a></blockquote><script async src="//s.imgur.com/min/embed.js" charset="utf-8"></script>


Still interested? Good. Now that we have an idea what the finished product will look like, lets discuss the actual software stack and my requirements. 

<< LINK TO MEDIADEPOT/DOCS >>

While this blog post will describe the step by step instructions for setting up CoreOS & Mediadepot, then [mediadepot/docs]() repo contains additional documentation that you might find interesting. 


Given that our goal of building the “the ultimate media server” is pretty hard to quantify, lets give ourselves some constraints and requirements that we can actually track. 

* The server will be self hosted, with only one physical node (if you need a multi-node media server, this wont work for you)
* The server will be running headless (no monitor is required)
* The server will be running a minimal OS/hypervisor. This is to limit the amount of OS maintenance required, and ensure that all software is run in a maintainable & isolated way.
* The server will be using JBOD disk storage (allowing you to aggregate and transparently interact with multiple physical disks as a single volume)
    * **Redundancy is should be supported but is not a requirement.**
* The server will provide a automation friendly folder structure for use by media managers (sickrage, couchpotato, sonar, plex, etc)
* The server will provide a monitoring solution with a web GUI.
* The server will provide a routing method to running web applications via a custom domain *.depot.lan
* The server will provide a method that user applications can use to notify the user when events have occurred (download started, completed, media added)
* The server will provide a way to backup application configuration to a secondary location.

The first two items on the list are already done. The hardware chosen in [Part 1]() was only for a single server. 
The headless requirement (#2) is solved by the IPMI functionality built into our SuperMicro X11SSL-CF motherboard. 

<< IMAGE of IPMI >>

IPMI provides us with the ability to remotely manage the server, including the ability to see what’s “running” on the server using a virtual display + KVM. 

Requirement #3 is where this blog post really starts. 
Rather than going with a traditional virtualization/hypervisor solution like ESXI or Proxmox, I’m going to evangelize the use of CoreOS Container Linux as the base Operating System for your Home Server

> What is CoreOS
> Its a 
