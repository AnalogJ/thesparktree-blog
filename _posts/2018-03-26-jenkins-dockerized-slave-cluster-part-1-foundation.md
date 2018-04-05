---
layout: post
title: 'Jenkins Kubernetes Cluster - Part 1 - Foundation'
date: '18-03-25T01:19:33-08:00'
cover: '/assets/images/cover_kubernetes.jpg'
subclass: 'post tag-post'
tags:
- devops
- automation
- github
- docker
- kubernetes
- openstack
- terraform
- jenkins
- cluster
- coreos

navigation: True
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

This is Part 1 in my tutorial to build a Dockerized Jenkins slave cluster leveraging modern technologies like Kubernetes, CoreOS and Terraform. If you haven't read the introductory post for this series, you should check it out first: [Jenkins Dockerized Slave Cluster - Premise]({% post_url 2018-03-25-jenkins-dockerized-slave-cluster %})

The goal for Part 1 is to configure our cloud provider (Openstack) and build a half dozen CoreOS servers using Terraform. These servers will then be the foundation upon which we build our Kubernetes cluster in Part 2 of this tutorial.

## Tech Stack

Terraform was chosen because it lets us define our infrastructure as code, with all the reusability, repeatability & maintenance benefits that implies. Its also very cloud agnostic, meaning you can migrate our Openstack implementation to the cloud provider of your choice. Unlike the configuration management world, there isn't really any other competition when it comes to infrastructure-as-code. 

CoreOS is a minimal linux distribution built for only one purpose - running Docker containers. Its stable, easy to install, simple to maintain and utterly forgettable once you have it configured. There's more competition in the minimal Docker OS space: Project Atomic,  Snappy, RancherOS, Photon. They're all valid options, honestly any OS that can run Docker is valid. However you'll want to take into account how much effort is required to define services and find supported binaries.   

OpenStack is an open source solution that lets you convert on-premise datacenter resources into an AWS/Azure/GCE-like private cloud. Its popular in large corporations, and can also integrate with public clouds directly. While this this tutorial is written for OpenStack, this series is not strictly tied to OpenStack. Only Part 1 interacts with OpenStack  and only though Terraform, which can be easily modified to leverage a public cloud of your choosing.

## Source Code

As with all my guides, the source code snippets from this tutorial are all available in a fully functional git repository.


## Getting Started

First lets get our development environment setup. You'll need to install the following tools:

- Python 2.7+
	- Using a package manager: `brew install python@2`
	- Download installer: https://www.python.org/downloads/
- Terraform CLI
	- Using a package manager: `brew install terraform`
	- Download binary: https://www.terraform.io/downloads.html
- OpenStack Glance (Image Service) CLI
	- `pip install python-glance/client`	

## OpenStack Credentials

- ref: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux_OpenStack_Platform/5/html/End_User_Guide/cli_openrc.html

While account signup varies by cloud provider, they all have the concept of API keys and authorization scopes. In OpenStack your credentials can be accessed under **Access & Security** > **API Access**, then click **Download OpenStack RC File**

![OpenStack Credentails](/assets/images/openstack-get-credentials.png)

This file will contain a set of credentials that are required to communicate with your OpenStack installation. The file helpfully assigns them to environmental variables, so you can easily import them into your terminal using `source PROJECT-openrc.sh`

```bash
​export OS_USERNAME=username
​export OS_PASSWORD=password
​export OS_TENANT_NAME=projectName
​export OS_AUTH_URL=https://identityHost:portNumber/v2.0
​# The following lines can be omitted
​export OS_TENANT_ID=tenantIDString
​export OS_REGION_NAME=regionName
```

Please note, this file will contain your account password in clear text, and should be protected as you would any other sensitive file. `$ chmod 600 PROJECT-openrc.sh`

Next lets test these credentials with our OpenStack CLI to ensure everything is working correctly.
`$ glance image-list`

## CoreOS image

- ref: https://coreos.com/os/docs/latest/booting-on-openstack.html

Unlike most public cloud providers which already have CoreOS images uploaded and maintained by the CoreOS team ([AWS](https://coreos.com/os/docs/latest/booting-on-ec2.html), [GHE](https://coreos.com/os/docs/latest/booting-on-google-compute-engine.html)), OpenStack is running in your own datacenter and the CoreOS image may not be available by default.

In that case, we'll need to download the latest stable image of CoreOS, extract it and then convert it to an image format that OpenStack understands before uploading it to OpenStack. 

We can do all this in a couple of bash commands. Note that this will require ample HD space (~15GB) and a good internet connection (you'll be uploading ~10GB to OpenStack).

```bash
# download the latest CoreOS image. 
# if you want to use a specific version, replace "current" with a version from this list:
# 	https://stable.release.core-os.net/amd64-usr/
$ wget https://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2

# extract the bz2 compressed file
$ bunzip2 coreos_production_openstack_image.img.bz2

# convert image to RAW type
$ qemu-img convert -f qcow2 -O raw coreos_production_openstack_image.img coreos_production_openstack_image.raw

# upload image to OpenStack

$ glance \
	image-create \
	--name cores-stable \
	--container-format bare \
	--disk-formate raw \
	--file coreos_production_openstack_image.raw
```

## Terraform Folder Structure

- ref: https://www.terraform.io/docs/enterprise/workspaces/repo-structure.html
- ref: https://www.terraform.io/docs/modules/usage.html
- ref: https://github.com/hashicorp/best-practices

Now that we have our OpenStack environment primed, its time to start working on the code to get our infrastructure up and running. The first thing we'll need to do is prepare a git repo with the following folder structure. While toy examples just throw everything in one file, its hard to untangle later on, and goes against Hashicorp's best practices for Terraform. Lets do it right, from the beginning. 

```
├── README.md
├── variables.tf
├── terraform.tfvars
├── main.tf
├── outputs.tf
├── modules
│   ├── compute
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── network
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── data
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
```

## Variables
Since I have the benefit of having working code already, I'm going to start backwards and talk about the different configuration variables we'll be defining for use in our Terraform files. These variables are what you can use to customize your CoreOS (and eventual Kubernetes) cluster to your needs, across various environments. 

```
path: /terraform.tf

# OpenStack variables

variable "os_username" {
	description = "Your OpenStack username"
} 

variable "os_password" {
	description = "Your OpenStack password"
}  

variable "os_tenant_id" {
	description = "Your OpenStack tenant id"
}

variable "os_auth_url" {
	description = "Your OpenStack auth url"
}

variable "os_region" {
	description = "Your OpenStack region"
}

# Project variables

variable "project_name" {
	description = "Prefix added to every resource created by this Terraform project"
	default = "test"
} 

variable "coreos_image_id" {
	description = "OpenStack id/name used when uploading CoreOS image"
	default = ""
}

variable "external_domain" {
	description = "Domain name you'll be using to access your cluster"
	default = "slave-cluster.corp.example.com"
} 

variable "public_key_path" {
	description "Path to your SSH public key"
	default = "~/.ssh/id_rsa.pub"
} 

# Network variables
variable "network_name" {
	description = "OpenStack pre-configured internal network for nodes"
	default = "internal"
} 

variable "lb_subnet_id" {
	description = "OpenStack pre-configured subnet ID to be used by Load Balancer"
} 
variable "lb_ip_address" {
	description = "IP address to be requested by Load Balancer"
} 


# Compute variables 
variable "compute_count" {
	description = "Number of slaves/nodes in your Kubernetes cluster"
	default = 3
}

variable "compute_flavor" {
	description = "OpenStack flavor (compute, memory, and storage capacity) for compute nodes"
	default = "m1.medium"
}

variable "controller_count" {
	description = "Number of controllers/masters in your Kubernetes cluster."
	default = 1
} 

variable "controller_flavor" {
	description = "OpenStack flavor (compute, memory, and storage capacity) for controller nodes"
	default = "m1.medium"
}

# Kubernetes variables

variable "cluster_join_token" {
	description = "Secure token used to join compute nodes to Kubernetes cluster. `[a-z0-9]{6}.[a-z0-9]{16}`"
} 

```

Now that you have a basic understanding of the different inputs available, its time to actually start writing terraform modules.

## Networking

The first module we're going to build is the networking module. Because there's no such thing as "one size fits all" when it comes to networking, we're going to constrain our solution a bit:

- We're going to connect all resources/machines to one network/subnet.
- We're going to assume that this network already exists. 
- This network should be "accessible" (via intranet or internet, thats up to you)
- Our security model will be based on security groups rather than discrete networks and multiple subnets.

This tutorial is designed to be secure by default, while still being understandable to a networking beginner.

So lets look at the network diagram:

![Network Diagram]()

Basically here's what we want:

- By default incoming traffic on any port is disabled, unless explicitly allowed
- Incoming SSH traffic (port 22) is allowed on all servers. We're authenticating via keypair which is secure, however you may want to disable this. 
- Incoming HTTPS traffic (port 443) to compute nodes is enabled. This is because we want to access the `kubernetes-dashboard`. 
- Incoming traffic on port 6443 to the controller node is enabled. This is the API server, which we'll be wiring up to Jenkins. 
- Nodes in the Compute security group can talk to the Controller security group. This is required since members of a cluster need to talk to each other. 

That's it. Now lets see those rules in Terraform configuration syntax. 




## Compute

## Configuration

## References
- https://www.terraform.io/docs/enterprise/workspaces/repo-structure.html
- https://www.terraform.io/docs/modules/usage.html
