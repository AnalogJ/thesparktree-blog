---
layout: post
title: HyperV How to allow remote access to MMC Snap Ins
date: '2011-10-03T00:00:00-07:00'
cover: 'assets/images/cover_microsoft.jpg'
subclass: 'post tag-fiction'
tags:
- HyperV
tumblr_url: http://blog.thesparktree.com/post/41986431131/hyperv-how-to-allow-remote-access-to-mmc-snap-ins
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'

---
http://blogs.technet.com/b/server_core/archive/2008/01/14/configuring-the-firewall-for-remote-management-of-a-workgroup-server-core-installation.aspx

Not every MMC snap-in has a firewall group, here are those that do:

<table class="MsoTableGrid" style="border-right: medium none; border-collapse: collapse; border: medium none -moz-use-text-color;" border="1" cellspacing="0" cellpadding="0"><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: 1pt solid black;" width="295" valign="top">MMC Snap-in</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: 1pt 1pt 1pt medium solid solid solid none black black black #f0f0f0;" width="295" valign="top">Rule Group</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Event Viewer</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">Remote Event Log Management</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Services</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">Remote Service Management</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Shared Folders</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">File and Printer Sharing</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Task Scheduler</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">Remote Scheduled Tasks Management</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Reliability and Performance </td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">“Performance Logs and Alerts” and “File and Printer Sharing”</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Disk Management</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">Remote Volume Management</td></tr><tr><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt none solid solid #f0f0f0 black black;" width="295" valign="top">Windows Firewall with Advanced Security</td><td style="border-right: 1pt solid black; padding: 0in 5.4pt; width: 221.4pt; background-color: transparent; border: medium 1pt 1pt medium none solid solid none #f0f0f0 black black #f0f0f0;" width="295" valign="top">Windows Firewall Remote Management</td></tr></table>On the Server Core box you can enable these by running:
Netsh advfirewall firewall set rule group=“<rule group>” new enable=yes
Where <rule group> is the name in the above table.

You can remotely enable these using the Windows Firewall with Advanced Security MMC snap-in, after you have locally on the Server Core box enabled the rule group to allow it to connect.

## MMC Snap-ins without a Rule Group

Not every MMC snap-in has a rule group to allow it access through the firewall, however many of them use the same ports for management as those that do. Therefore, you will find that enabling the rules for Event Viewer, Services, or Shared Folders will allow most other MMC snap-ins to connect. Of course, you can also simply enable the remote administration rule group (see my last post).

## MMC Snap-ins that Require Addition Configuration

In addition to allowing the MMC snap-ins through the firewall, the following MMC snap-ins require additional configuration:

## Device Manager

To allow Device Manager to connect, you must first enable the “Allow remote access to the PnP interface” policy
1.    On a Windows Vista or full Server installation, start the Group Policy Object MMC snap-in
2.    Connect to the Server Core installation
3.    Navigate to Computer Configuration\Administrative Templates\Device Installation
4.    Enable “Allow remote access to the PnP interface”
5.    Restart the Server Core installation

## Disk Management
You must first start the Virtual Disk Service (VDS) on the Server Core installation

## IPSec Mgmt
On the Server Core installation you must first enable remote management of IPSec. This can be done using the scregedit.wsf script:
Cscript \windows\system32\scregedit.wsf /im 1
