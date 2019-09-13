---
layout: post
title: 'Docker Hub - Matrix Builds and Tagging using Build Args'
date: '19-01-25T01:19:33-08:00'
cover: '/assets/images/cover_docker_hub.png'
subclass: 'post tag-post'
tags:
- docker
- docker_hub
- devops
- linux
- automation

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
hidden: true
---

If you're a heavy user of Docker, you're already intimately familiar with Docker Hub, the official Docker Image registry.
One of the best things about Docker Hub is it's support for Automated Builds, which is where Docker Hub will watch a
Git repository for changes, and automatically build your Docker images whenever you make a new commit.

This works great for most simple use cases (and even some complex ones), but occasionally you'll wish you had a bit more control
over the Docker Hub image build process.

That's where Docker's [Advanced options for Autobuild and Autotest](https://docs.docker.com/docker-hub/builds/advanced/)
guide comes in. While it's not quite a turn key solution, Docker Hub allows you to override the `test`, `build` and `push`
stages completely, as well as run arbitrary code `pre` and `post` each of those stages.


## Goal

So what's the point? If Docker Hub works fine for most people, what's an actual use case for these Advanced Options?

Lets say you have developed a tool, and you would like to distribute it as a Docker image. The first problem is that you'd
like to provide Docker images based on a handful of different OS's. `ubunut`, `centos6`, `centos7` `alpine` and `windows-nano`.
Simple enough, just write a handful of Dockerfiles, and use the `FROM` instruction.
But lets say that you also need to provide multiple versions of your tool, and each of those must also be distributed as a
Docker Image based on different OS's.

Now the number of Dockerfiles you need to maintain has increased significantly. If you're familiar with Jenkins, this would
be perfect for a "Matrix Project".

Here's what our Docker naming scheme might look like:

|      | ubuntu    | centos6    | centos7    | alpine    | windows-nano    |
|------|-----------|------------|------------|-----------|-----------------|
| v1.x | v1-ubuntu | v1-centos6 | v1-centos7 | v1-alpine | v1-windows-nano |
| v2.x | v2-ubuntu | v2-centos6 | v2-centos7 | v2-alpine | v2-windows-nano |
| v3.x | v3-ubuntu | v3-centos6 | v3-centos7 | v3-alpine | v3-windows-nano |

As our software grows, you could image other axises being added: architectures, software runtimes, etc.

## Build Arguments

Alright, so the first part of the solution is just making use of Dockerfile templating, also known as [build arguments](https://docs.docker.com/engine/reference/commandline/build/#set-build-time-variables---build-arg)

To keep the number of Dockerfiles to the minimum, we need to pick an axes that minimizes the number of changes required.
In this example we'll choose to create a separate Dockerfile for each OS, reusing it for each branch of our software.

```Dockerfile
FROM ubuntu
ARG software_version

RUN apt-get update && apt-get install -y <dependencies> \
    ... \
    curl -o /usr/bin/myapp https://www.company.com/${software_version}/myapp-${software_version}

```

Now we can reuse this single Dockerfile to build 3 Docker images, running 3 different versions of our software:

```
docker build -f ubuntu/Dockerfile --build-arg software_version=v1.0 -t v1-ubuntu .
docker build -f ubuntu/Dockerfile --build-arg software_version=v2.1 -t v2-ubuntu .
docker build -f ubuntu/Dockerfile --build-arg software_version=v3.7 -t v3-ubuntu .
```

# Docker Hub Hook Scripts
Looks great so far, but Docker Hub doesn't support 
