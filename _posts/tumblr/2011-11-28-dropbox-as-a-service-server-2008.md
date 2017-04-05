---
layout: post
title: Dropbox as a service Server 2008
date: '2011-11-28T00:00:00-08:00'
cover: '/assets/images/cover_dropbox.jpg'
subclass: 'post tag-post'
tags:
- Dropbox
- Service
redirect_from:
- /post/41987942679/dropbox-as-a-service-server-2008
- /post/41987942679
disqus_id: 'http://blog.thesparktree.com/post/41987942679'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---

**What I did**
So here are the steps that I took in order to get everything working. Quite a few steps but I wanted it detailed enough so that anyone could follow.

- Right click the Dropbox icon in your system tray and select Preferences
- Deselect Show desktop notifications
- Deselect Start Dropbox on system startup
- Download and install Windows Server 2003 Resource Kit Tools. It will warn you about incompatibility, but you can safely ignore this (or at least I did).
- Open the Command Console (Run –&gt; cmd).
- Enter sc create DropboxService binPath= C:\Program Files (x86)\Windows Resource Kits\Tools\srvany.exe DisplayName= "Dropbox Service"
- Open RegEdit and navigate to HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DropboxService\
- Create a new key named Parameters
- Create a string value called Application and enter the full path to your Dropbox executable. Typically C:\Users\****\AppData\Roaming\Dropbox\bin\Dropbox.exe
- Open Services (Start Menu –&gt; Administrative Tools –&gt; Services)
- Locate your Dropbox Service, right click and select properties.
- Set the service to Autostart
- Under the Log on tab, check Allow service to interact with desktop.
- Press Apply
- Start the service
- You will get a popup asking for permissions to display the Dropbox configuration - Accept.
- Add your user info

Done!

<hr>

- Download Windows Server 2003 Resource Kit Files (2008 can use these)
- Install it into my own workstation, copied files srvany and instsrv into server C:\windows\system32
- Start command prompt with elevated rights with the *user of choice*
- Install : "Dropbox 1.1.45.exe" /D=C:\Program Files\Dropbox
- Run through setup, determine local folder etc
- Start Dropbox, Preferences -&gt; uncheck "Show desktop notifications" and "Start Dropbox on system startup"
- Exit dropbox
- Create Service -&gt; C:\Windows\System32\instsrv.exe" DropBoxService "C:\Windows\System32\srvany.exe -&gt; Success
- Regedit -&gt; HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DropBoxService
- Create KEY Parameters
- Create String value "Application", value C:\Program Files\Dropbox\Dropbox.exe /home
- Create String value AppDirectory, value C:\Program Files\Dropbox
- Services -&gt; DropBoxService -&gt; Properties -&gt; Log on -&gt; Use *user of choice*
- Start service