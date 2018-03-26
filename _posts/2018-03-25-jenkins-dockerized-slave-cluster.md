---
layout: post
title: 'Jenkins Dockerized Slave Cluster - Premise'
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

Here's the premise, we have one or more Jenkins masters running our various jobs, and we've bottlenecking the server: the UI is sluggish, and builds are taking longer than normal. The obvious answer is to add slaves. But multiple Jenkins masters, each with their own dedicated slaves is a lot of compute power, which may be idle most of the time, meaning a lot of wasted money and resources. 

Wouldn't it be nice if we could share slave nodes between the masters? Create a cluster of slave nodes and have the various Jenkins masters run their jobs without needing to worry about scheduling or the underlying utilization of the hardware?

Enter buzzword heaven. In the next few posts I'll be going through all the steps required to build a Dockerized Jenkins slave cluster. 

- Part 1 - Our cloud provider will be OpenStack, however we'll be using Terraform for provisioning, so you could easily migrate my tutorial onto Azure/AWS/GCE or Bare Metal. Our foundation will be a half-dozen vanilla CoreOS machines, which you can resize to your needs.
- Part 2 - On top of that we'll use kubeadm to bootstrap a best-practice Kubernetes cluster in an easy, reasonably secure and extensible way. No complex configuration-management required.
- Part 3 - Finally, we'll configure our Jenkins masters to communicate with a single Kubernetes cluster. The Jenkins masters will run jobs in a "cloud" that will transparently spin up Docker containers on demand. Once the job finishes the container is destroyed automatically, freeing up those resources for other masters and their jobs. 

My goal with these posts are to:

1. Aggregate all the steps in one place. There's alot of smart people out there who've written various guides doing each of these things individually. I want to aggregate all the steps into one, easy to follow along tutorial
2. Break each stage up into comprehendible chunks, and clearly explain how they interact with each other. This allows you to modify my tutorial to suit your needs, while still being able to follow along.
3. Provide a real code repository, not just snippets out of context. Sometimes the "obvious" glue code isn't so obvious. A repo you can grep can save a lot of time. 
4. Write a continiously updated/evergreen guide following modern best practices. Like code, content also rots -- especially quick in the devops & docker world. I'll be keeping this guide as up-to-date as possible. In addition it's hosted on Github, so you can submit edits to make each post better. 


