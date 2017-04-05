---
layout: post
title: Hyper-V Server Injecting Network Drivers
date: '2011-09-30T00:00:00-07:00'
cover: '/assets/images/cover_microsoft.jpg'
subclass: 'post tag-post'
tags:
- HyperV
redirect_from: /post/41985876443/hyper-v-server-injecting-network-drivers
disqus_id: 'http://blog.thesparktree.com/post/41985876443'
categories: 'analogj'
navigation: True
logo: '/assets/logo-dark.png'

---
How to inject network drivers into HyperV Server when you see the message “No active network adapters found”

Download device driver
Change Directory to driver location
`execute pnputil -i -a driverfile.inf`
