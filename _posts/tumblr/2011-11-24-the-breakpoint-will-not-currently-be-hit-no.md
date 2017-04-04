---
layout: post
title: The breakpoint will not currently be hit. No symbols have been loaded for this
  document.
date: '2011-11-24T00:00:00-08:00'
cover: 'assets/images/cover_visual_studio.png'
subclass: 'post tag-fiction'
tags:
- ASP.Net
- C
redirect_from: /post/41987546374/the-breakpoint-will-not-currently-be-hit-no
disqus_id: 'http://blog.thesparktree.com/post/41987546374'
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'

---
I'm posting this blog mostly to remind myself how to fix this if ever I run into it again, but if anyone else benefits from it, then awesome.

In the Visual Studio IDE, when I set a breakpoint at a line of code, and start debugging, the breakpoint becomes that hollow maroon circle with a warning that says The breakpoint will not currently be hit. No symbols have been loaded for this document.

I've read a bunch of articles about makiing sure you're running in debug versus release mode, and making sure you deleted your obj AND bin folders. None of that worked for me. After some digging, and some help from [John Alexander](http://geekswithblogs.net/jalexander) and [Jeff Julian](http://geekswithblogs.net/jjulian), I found one way that works for me.

- While debugging in Visual Studio, click on Debug &gt; Windows &gt; Modules. The IDE will dock a Modules window, showing all the modules that have been loaded for your project.
- Look for your project's DLL, and check the Symbol Status for it.
- If it says Symbols Loaded, then you're golden. If it says something like Cannot find or open the PDB file, right-click on your module, select Load Symbols, and browse to the path of your PDB.

I've found that it's sometimes necessary to

- stop the debugger
- close the IDE
- close the hosting application
- nuke the obj and bin folders
- restart the IDE
- rebuild the project
- go through the Modules window again

Once you browse to the location of your PDB file, the Symbol Status should change to Symbols Loaded, and you should now be able to set and catch a breakpoint at your line in code.

- From : [http://geekswithblogs.net/dbutscher/archive/2007/06/26/113472.aspx](http://geekswithblogs.net/dbutscher/archive/2007/06/26/113472.aspx)
