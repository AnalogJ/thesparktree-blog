---
layout: post
title: NodeJS on the Windows Azure Cloud, Start to Finish
date: '2013-09-28T14:43:00-07:00'
cover: '/assets/images/cover_nodejs.jpg'
subclass: 'post tag-post'
tags:
- azure
- nodejs
- javascript
redirect_from: /post/62530881389/nodejs-on-the-windows-azure-cloud-start-to-finish
disqus_id: 'http://blog.thesparktree.com/post/62530881389'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---

So you want to run nodejs on a linux image on Azure, easy right?
Well.. kinda..

# NodeJS on the Windows Azure Cloud, Start to Finish

## Remote In

The first step to setting up your nodejs application is to remote into your linux image. I've taken the following steps from the great guide on [windowsazure.com](http://www.windowsazure.com/en-us/manage/linux/how-to-guides/log-on-a-linux-vm/)

For a virtual machine that is running the Linux operating system, you use a Secure Shell (SSH) client to logon.

You must install an SSH client on your computer that you want to use to log on to the virtual machine. There are many SSH client programs that you can choose from. The following are possible choices:

- If you are using a computer that is running a Windows operating system, you might want to use an SSH client such as PuTTY. For more information, see the [PuTTY Download Page](http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html).
- If you are using a computer that is running a Linux operating system, you might want to use an SSH client such as OpenSSH. For more information, see [OpenSSH](http://www.openssh.org/).

This procedure shows you how to use the PuTTY program to access the virtual machine.

1. Find the __Host Name__ and __Port information__ from the [Management Portal](http://manage.windowsazure.com/). You can find the information that you need from the dashboard of the virtual machine. Click the virtual machine name and look for the __SSH Details__ in the __Quick Glance__ section of the dashboard.
2. Open the PuTTY program.
3. Enter the Host Name and the Port information that you collected from the dashboard, and then click __Open__.
4. Log on to the virtual machine using the account that you specified when the machine was created.

## Configuration + Prerequisites

If your coming from a non-unix background some of the following commands might be new to you.

1. Setup your new `root` password

    ```bash
	sudo passwd root
	# Changing password for user root.
	# New password:
	```

2. Change to the root account, enter the password you created for the `root` account previously

    ```bash
	su -
	# Password:
	```

3. Update installed packages

	```bash
	yum -y update
	```

4. Install development packages

    ```bash
	yum install kernel-headers --disableexcludes=all
	yum install gcc
	yum install gcc-c++
	yum -y groupinstall "Development Tools"
	```

    Trying to install `gcc` or the `development tools` without installing the kernel-headers package will result in the helpful `gcc (updates) Requires: kernel-headers` error. Note the `development tools` command produced a single error for me, but everything else still worked.

5. Install OpenSSL

	```
    yum install openssl-devel
	```

6. Download and extract NodeJS

    ```bash
	cd /usr/src
	wget http://nodejs.org/dist/node-latest.tar.gz
	tar zxvf node-latest.tar.gz
	```

7. Change working directory into the extracted folder:

    ```
	cd node-v0.10.3
	```

8. Install NodeJS

	```bash
	./configure
	make
	make install
	```

9. Verify installation

	```bash
	node -v
	npm -v
	```

## Setup Git

1. Install git. Unfortunately the version of git accessible by `yum` is out of date. So you can't do:

    <strike>yum install git</strike>

	Its ok though, we can just build it from source. I've tried few methods, most of them from this [SO question](http://stackoverflow.com/questions/3779274/how-can-git-be-installed-on-centos-5-5) but most of them failed on my CentOs, either because of the wrong repos or missing files.

	```bash
	yum -y install zlib-devel openssl-devel cpio expat-devel gettext-devel
	wget http://git-core.googlecode.com/files/git-1.8.4.tar.gz
	tar -xzvf ./git-1.8.4.tar.gz
	cd ./git-1.8.4
	./configure
	make
	make install
	```

    You may want to download a different version from here: [http://code.google.com/p/git-core/downloads/list](http://code.google.com/p/git-core/downloads/list)

## Setup Github SSH Key
The following instructions were taken from the [Generating SSH Keys](https://help.github.com/articles/generating-ssh-keys) page on Github

1. Check for existing SSH keys

	```bash
	cd ~/.ssh
	ls
	# Lists the files in your .ssh directory
	```

    Check the directory listing to see if you have a file named either `id_rsa.pub` or `id_dsa.pub`. If you don't have either of those files go to __step 2__. Otherwise, you already have an existing keypair, and you can skip to __step 3__.

2. Generate a new SSH key

    To generate a new SSH key, enter the code below. We want the default settings so when asked to enter a file in which to save the key, just press enter.

    ```bash
	ssh-keygen -t rsa -C "your_email@example.com"
	// Creates a new ssh key, using the provided email as a label
	# Generating public/private rsa key pair.
	# Enter file in which to save the key (/c/Users/you/.ssh/id_rsa): [Press enter]
	ssh-add id_rsa
	```

    Now you need to enter a passphrase.

	```
	# Enter passphrase (empty for no passphrase): [Type a passphrase]
	# Enter same passphrase again: [Type passphrase again]
	```

    Which should give you something like this:

	```
	# Your identification has been saved in /c/Users/you/.ssh/id_rsa.
	# Your public key has been saved in /c/Users/you/.ssh/id_rsa.pub.
	# The key fingerprint is:
	# 01:0f:f4:3b:ca:85:d6:17:a1:7d:f0:68:9d:f0:a2:db your_email@example.com
	```

3. Add your SSH key to GitHub

    Run the following code to view your public key.

    <!-- code[bash] -->

        cat ~/.ssh/id_rsa.pub

    Copy and paste the output of the cat command into the [Add SSH Key](https://github.com/settings/ssh) window.

4. Test your key on Github

    <!-- code[bash] -->

        ssh -T git@github.com
        // Attempts to ssh to github
        # The authenticity of host 'github.com (207.97.227.239)' can't be established.
        # RSA key fingerprint is 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48.
        # Are you sure you want to continue connecting (yes/no)?
        # yes
        # Hi AnalogJ! You've successfully authenticated, but GitHub does not provide shell access.

## Clone your Git(Hub) Repo
Create your (web) application directory and clone project


```
cd /srv
mkdir www
cd www
git clone git@github.com:AnalogJ/docker-node-hello.git hello
cd hello
make install
make run
```

## Open up Firewall

Firewalled ports can only be opened by configuring them in the management console in Azure.
You can click find the full guide on [setting up your azure endpoints](http://www.windowsazure.com/en-us/manage/windows/how-to-guides/setup-endpoints/)

1. If you have not already done so, sign in to the Windows Azure Management Portal.

2. Click __Virtual Machines__, and then select the virtual machine that you want to configure.

3. Click __Endpoints__. The Endpoints page lists all endpoints for the virtual machine.

4. Click __Add__.

The Add Endpoint dialog box appears. Choose whether to add the endpoint to a load-balanced set and then click the arrow to continue.

5. In __Name__, type a name for the endpoint.

6. In protocol, specify either __TCP__ or __UDP__.

7. In __Public Port__ and __Private Port__, type port numbers that you want to use. These port numbers can be different. The public port is the entry point for communication from outside of Windows Azure and is used by the Windows Azure load balancer. You can use the private port and firewall rules on the virtual machine to redirect traffic in a way that is appropriate for your application.

8. Click __Create a load-balancing set__ if this endpoint will be the first one in a load-balanced set. Then, on the __Configure the load-balanced set__ page, specify a name, protocol, and probe details. Load-balanced sets require a probe so the health of the set can be monitored. For more information, see [Load Balancing Virtual Machines](http://www.windowsazure.com/en-us/manage/windows/common-tasks/how-to-load-balance-virtual-machines/).

9. Click the check mark to create the endpoint.

You will now see the endpoint listed on the Endpoints page.


