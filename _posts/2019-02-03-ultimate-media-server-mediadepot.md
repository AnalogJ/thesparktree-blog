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
- **[Part 3 - MediaDepot/CoreOS Configuration](/ultimate-media-server-build-mediadepot)**
- Part 4 - Application Docker Containers

This is **Part 3**, where I'll be discussing the software I use to run my ultimate media server, specifically focusing on installing and
configuring CoreOS for MediaDepot.

---


<blockquote class="imgur-embed-pub" lang="en" data-id="a/VMcMtVY"><a href="//imgur.com/VMcMtVY"></a></blockquote><script async src="//s.imgur.com/min/embed.js" charset="utf-8"></script>