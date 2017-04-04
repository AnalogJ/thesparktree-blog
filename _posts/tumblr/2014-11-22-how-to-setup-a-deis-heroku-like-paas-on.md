---
layout: post
title: How to setup a Deis (Heroku-like PAAS) on Microsoft Azure using CoreOS
date: '2014-11-22T00:04:00-08:00'
cover: 'assets/images/cover_deis.jpg'
subclass: 'post tag-fiction'
tags:
- coreos
- deis
- azure
- docker
- devops
redirect_from: /post/103257786994/how-to-setup-a-deis-heroku-like-paas-on
disqus_id: 'http://blog.thesparktree.com/post/103257786994'
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'
---
# Prerequisites

##Install and Configure the Azure CLI

```bash
# If Node.js is installed on your system, use the following command to install the xplat-cli:
sudo npm install azure-cli -g

#To download the publish settings for your account, use the following command:
azure account download

#This will open your default browser and prompt you to sign in to the Azure Management Portal. After signing in, a .publishsettings file will be downloaded. Make note of where this file is saved.

#Next, import the .publishsettings file by running the following command, replacing [path to .publishsettings file] with the path to your .publishsettings file:
azure account import [path to .publishsettings file]
```

## Azure Configuration
Ok, we're ready to provision our cluster. We'll first need to create an affinity group for this cluster so the hosts selected for the CoreOS VMs are close to each other:

    azure account affinity-group create myapp-affinity -l "East US" -e "MyApp Affinity Group"

Next, create a cloud service for this cluster. We are going to assign containers to each of the hosts in this cluster to serve web traffic so we want to load balance incoming requests across them using a cloud service. This cloud service name needs to be unique across all of Azure, so choose a unique one:

    azure service create --affinity-group myapp-affinity myapp-cloud-service-name

Finally, we will create a virtual private network for our cluster to live inside.

    #TODO: this isnt working
    azure network vnet create --affinity-group myapp-affinity myapp-network

## Configure CoreOS cloud-config.yml file

The first thing we need to do is get a discovery token for etcd. 'etcd' is a distributed key-value store built on the Raft protocol and acts as a store for configuration information for CoreOS. Fleet, another part of the CoreOS puzzle, is a low-level init system built on 'etcd' that provides the functionality of Systemd over a distributed cluster.

This discovery token is configured in the cloud-init file called cloud-config.yml. This configures the CoreOS image once it is provisioned by Azure and, in particular, it injects the etcd discovery token into the virtual machine so that it knows which CoreOS cluster it belongs to. Its important to have a new and unique value for this, otherwise your cluster could fail to initialize correctly.

Let's provision a new one for our cluster:

    curl https://discovery.etcd.io/new

This will fetch a discovery URL that looks something like https://discovery.etcd.io/e6a84781d11952da545316cb90c9e9ab. Copy this and edit the [cloud-config.yml](https://raw.githubusercontent.com/deis/deis/master/contrib/coreos/user-data.example) file and paste this discovery token into it.

[Dies Cloud-Config Example File](https://raw.githubusercontent.com/deis/deis/master/contrib/coreos/user-data.example)

## Create Azure CoreOS VM Cluster

Run the folllowing commands to create your Azure VMs. Feel free to configure the size and ports, but be sure to create atleast 3 vms. Deis provisions 3 router services by default, and will hang if only less than 3 servers are present. (https://github.com/deis/deis/issues/2469)

```bash
azure vm create \
--custom-data=cloud-config.yml \
--vm-size=Basic_A1 \
--ssh=22 \
--ssh-cert=../path/to/cert \
--no-ssh-password \
--vm-name=coreos1 \
--virtual-network-name=myapp-network \
--affinity-group=myapp-affinity \
myapp-cloud-service-name \
2b171e93f07c4903bcad35bda10acf22__CoreOS-Beta-494.0.0 \
core

azure vm create \
--custom-data=cloud-config.yml \
--vm-size=Basic_A1 \
--ssh=2222 \
--ssh-cert=../path/to/cert \
--no-ssh-password \
--vm-name=coreos2 \
--virtual-network-name=myapp-network \
--affinity-group=myapp-affinity \
--connect
myapp-cloud-service-name \
2b171e93f07c4903bcad35bda10acf22__CoreOS-Beta-494.0.0 \
core

azure vm create \
--custom-data=cloud-config.yml \
--vm-size=Basic_A1 \
--ssh=2223 \
--ssh-cert=../path/to/cert \
--no-ssh-password \
--vm-name=coreos3 \
--virtual-network-name=myapp-network \
--affinity-group=myapp-affinity \
--connect
myapp-cloud-service-name \
2b171e93f07c4903bcad35bda10acf22__CoreOS-Beta-494.0.0 \
core
```


Use the following command to find alternative/newer versions of CoreOS

    azure vm image list | grep  "CoreOS"

Let's quickly ssh into the first machine in the cluster and check to make sure everything looks ok:

    ssh core@myapp-cloud-service-name.cloudapp.net -p 22 -i ../path/to/cert

Let's first make sure etcd is up and running:

```
sudo etcdctl ls --recursive
# /coreos.com
# /coreos.com/updateengine
# /coreos.com/updateengine/rebootlock
# /coreos.com/updateengine/rebootlock/semaphore
```

And that fleetctl knows about all of the members of the cluster:

```
sudo fleetctl list-machines
# MACHINE     IP      METADATA
# 36a636af... 10.0.0.4    region=us-east
# 40078616... 10.0.0.5    region=us-east
# f6ebd7d1... 10.0.2.4    region=us-east
```

Finally lets exit from the CoreOS cluster and install the local management tools

    exit

## Install Deis Control Utility
The Deis Control Utility, or `deisctl` for short, is a command-line client used to configure and manage the Deis Platform.

### Building from Installer

To install the latest version of deisctl, change to the directory where you would like to install the binary. Then, install the Deis Control Utility by downloading and running the install script with the following command:

```
mkdir /tmp/deisctl
cd /tmp/deisctl
curl -sSL http://deis.io/deisctl/install.sh | sh -s 1.0.1
```

This installs deisctl to the current directory, and refreshes the Deis systemd unit files used to schedule the components. Link it to /usr/local/bin, so it will be in your PATH:

    cp /tmp/deisctl/deisctl /usr/local/bin/deisctl

Always use a version of deisctl that matches the Deis release. Verify this with `deisctl --version`.

## Install the Deis Platform

Ensure your SSH agent is running and select the private key that corresponds to the SSH key added to your CoreOS nodes:

```bash
eval `ssh-agent -s`
ssh-add ~/.ssh/deis
```

Export it to the DEISCTL_TUNNEL environment variable (substituting your own cloud app service name):

    export DEISCTL_TUNNEL="myapp-cloud-service-name.cloudapp.net"

This is the IP address where deisctl will attempt to communicate with the cluster. You can test that it is working properly by running deisctl list. If you see a single line of output, the control utility is communicating with the nodes.

Before provisioning the platform, we’ll need to add the SSH key to Deis so it can connect to remote hosts during deis run:

    deisctl config platform set sshPrivateKey=~/.ssh/deis

We’ll also need to tell the controller which domain name we are deploying applications under:

    deisctl config platform set domain=example.com

Once finished, run this command to provision the Deis platform:

    deisctl install platform

You will see output like the following, which indicates that the units required to run Deis have been loaded on the CoreOS cluster:

```
● ▴ ■
■ ● ▴ Installing Deis...
▴ ■ ●

Scheduling data containers...
...
Deis installed.
Please run `deisctl start platform` to boot up Deis.
```

Run this command to start the Deis platform:

    deisctl start platform

Once you see “Deis started.”, your Deis platform is running on a cluster! You may verify that all of the Deis units are loaded and active by running the following command:

    deisctl list

All of the units should be active.

Now that you’ve finished provisioning a cluster, we can get started using the platform.



## References

- http://azure.microsoft.com/en-us/documentation/articles/xplat-cli/
- https://coreos.com/docs/launching-containers/launching/fleet-using-the-client/
- https://coreos.com/docs/running-coreos/cloud-providers/azure/
- https://github.com/timfpark/coreos-azure
- http://docs.deis.io/en/latest/installing_deis/install-deisctl/
- http://docs.deis.io/en/latest/installing_deis/install-platform/