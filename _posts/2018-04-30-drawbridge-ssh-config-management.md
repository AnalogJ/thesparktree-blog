---
layout: post
title: 'Drawbridge - SSH Config management for Jump/Bastion hosts'
date: '18-04-30T01:19:33-08:00'
cover: '/assets/images/cover_drawbridge.png'
subclass: 'post tag-post'
tags:
- devops
- automation
- github
- cloud
- aws
- jumphost
- bastion
- gce
- azure

navigation: True
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

In our architecture we have many environments (test/stage/prod/etc), and each environment can have one or more shards, usually broken up by datacenter/avaliablity zone (us-east-1, us-west-2, etc). Each of our shards are protected by Jump/Bastion hosts, auditing and restricting SSH access to internal components. 

For ease of use, tunneling into bastion host protected stacks is usually done by adding entries into your `~/.ssh/config` file, however when you start adding dozens of entries, it can be confusing and time consuming. 

A while back I made a post on [/r/devops](https://www.reddit.com/r/devops/comments/8aasuw/tools_for_interacting_withmaintaining_configs_for/) asking for help finding a tool that would manage/generate ssh config files for all our jump/bastion hosts. 

There was some interest (and great discussion), however no-one submitted a tool that solved the actual problem. 

Since that post, I've worked on an open source tool that implents everything required to work with Bastion/Jump hosts efficiently as a Developer or member of Operations. Its available now on github: [Drawbridge](https://github.com/AnalogJ/drawbridge)

## Here are some of its features:

- Single binary (available for macOS and linux), only depends on `ssh`, `ssh-agent` and `scp`
- Uses customizable templates to ensure that Drawbridge can be used by any organization, in any configuraton
- Helps organize your SSH config files and PEM files
- Generates SSH Config files for your servers spread across multiple environments and stacks.
	- multiple ssh users/keypairs
	- multiple environments
	- multiple stacks per environment
	- etc..
- Can be used to SSH directly into an internal node, routing though bastion, leveraging SSH-Agent
- Able to download files from internal hosts (through the jump/bastion host) using SCP syntax
- Supports HTTP proxy to access internal stack urls.
- Lists all managed config files in a heirarchy that makes sense to your organization
- Custom templated files can be automatically generated when a new SSH config is created.
	- eg. Chef knife.rb configs, Pac/Proxy files, etc.
- Cleanup utility is built-in
- `drawbridge update` lets you update the binary inplace.
- Pretty colors. The CLI is all colorized to make it easy to skim for errors/warnings


---

You can read more & download it from Github [https://github.com/AnalogJ/drawbridge]

I'm always open to PR's and feature requests. I'd also love to hear any feedback you guys may have
