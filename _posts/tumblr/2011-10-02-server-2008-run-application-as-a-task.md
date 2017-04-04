---
layout: post
title: Server 2008 Run Application as a Task
date: '2011-10-02T00:00:00-07:00'
cover: 'assets/images/cover_microsoft.jpg'
subclass: 'post tag-fiction'
tags:
- WHS2011
redirect_from: /post/41987099542/server-2008-run-application-as-a-task
disqus_id: 'http://blog.thesparktree.com/post/41987099542'
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'

---
Task Schedule works great in WHS 2011 (free an simple)

Server Manager (near start menu)

Drill down to, Configuration, Task Scheduler
click Create Task. (not the Basic one)
Give it name, click Run whether user is logged in or not, configure for  - Windows 7, 2008
Triggers Tab

New, (drop down menu) Begin the task at startup, click ok
Actions Tab

New, Start a program, Browse (to .exe) click ok
Conditions Tab

Uncheck the box that says to Stop the task if ran for 3 days. (so it runs forever)
Back to General Tab

Click ok and it will prompt for Administrator password
Click Task Scheduler Library (underneath Task Scheduler in Server Manager from step 1)

Run it ! (should work when you reboot too) I see my program running in task manager, so far so good!)

from: http://jack.ukleja.com/utorrent-service-windows-home-server-2011/
