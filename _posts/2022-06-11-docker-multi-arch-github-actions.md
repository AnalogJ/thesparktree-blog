---
layout: post
title: 'Building Multi-Arch Docker Images via Github Actions'
date: '22-06-11T01:19:33-08:00'
cover: '/assets/images/cover_arm_docker_github.png'
subclass: 'post tag-post'
tags:
- docker
- github
- arm

navigation: True
toc: true
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

I recently found myself needing to generate a multi-arch Docker image for one of my projects - specifically an ARM64 compatible image.
While its well known that Docker's `buildx` tooling supports multi-arch builds, it can be complicated getting it working correctly
via Github Actions. 

## What is a Multi-Arch Docker Image?

Before we go any further, we should discuss how Docker Images (& Multi-Arch Docker Images) actually work. 

> Each Docker image is represented by a manifest. A manifest is a JSON file containing all the information about a Docker 
> image. This includes references to each of its layers, their corresponding sizes, the hash of the image, its size and 
> also the platform it’s supposed to work on. This manifest can then be referenced by a tag so that it’s easy to find.

A multi-arch image is actually just a manifest that contains multiple entries, 1 for each platform. 

<img src="{{ site.url }}/assets/images/docker-multi-arch-manifest.png" alt="docker multi-arch manifest" style="max-height: 500px;"/>

To learn more, see this [Docker blog post](https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/)

## Basic Docker Build via Github Actions

Now that we know what a multi-arch docker image looks like under the hood, lets get started with a simple Github Action
to build a Docker image. 

```yaml
name: Docker
on:
  push:
    branches: ['main']
jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
      - name: Login to DockerHub
        uses: docker/login-action@v2
        with:
          username: {% raw %}${{ secrets.DOCKERHUB_USERNAME }}{% endraw %}
          password: {% raw %}${{ secrets.DOCKERHUB_TOKEN }}{% endraw %}
      - name: Build and push
        uses: docker/build-push-action@v3
        with:
          push: true
          tags: user/app:latest
```

## Migrate to Buildx

The first thing we need to do is add the `setup-buildx-action` step. 

> Docker Buildx is a CLI plugin that extends the docker command with the full support 
> of the features provided by Moby BuildKit builder toolkit. It provides the same 
> user experience as docker build with many new features like creating scoped 
> builder instances and building against multiple nodes concurrently.

Unfortunately Buildx is not enabled by default, so even though `docker` is available in our Github Action VM, we'll need to enable `buildx` mode. 


```diff
--- workflow.yaml       2022-06-12 08:09:34.000000000 -0700
+++ workflow-updated.yaml       2022-06-12 08:10:12.000000000 -0700
@@ -1,20 +1,22 @@
 name: Docker
 on:
   push:
     branches: ['main']
 jobs:
   docker:
     runs-on: ubuntu-latest
     steps:
       - name: Checkout repository
         uses: actions/checkout@v3
+      - name: Set up Docker Buildx
+        uses: docker/setup-buildx-action@v2
       - name: Login to DockerHub
         uses: docker/login-action@v2
         with:
           username: {% raw %}${{ secrets.DOCKERHUB_USERNAME }}{% endraw %}
           password: {% raw %}${{ secrets.DOCKERHUB_TOKEN }}{% endraw %}
       - name: Build and push
         uses: docker/build-push-action@v3
         with:
           push: true
           tags: user/app:latest
\ No newline at end of file
```

## QEMU Support
After enabling `buildx`, the next change we need to make is to enable `QEMU`. 

> QEMU is a free and open-source emulator. It can interoperate with Kernel-based 
> Virtual Machine (KVM) to run virtual machines at near-native speed. QEMU can also 
> do emulation for user-level processes, allowing applications compiled for one 
> architecture to run on another

GitHub Actions only provides a small set of host system types: [`windows`, `macos` & `ubuntu`](https://github.com/actions/virtual-environments) -- all running on `x86_64` architecture. 
If you need to compile binaries/Docker images for other OS's or architectures, you can use the `QEMU` Github Action.

```diff
--- workflow.yaml       2022-06-12 08:32:32.000000000 -0700
+++ workflow-updated.yaml       2022-06-12 08:32:56.000000000 -0700
@@ -1,22 +1,26 @@
 name: Docker
 on:
   push:
     branches: ['main']
 jobs:
   docker:
     runs-on: ubuntu-latest
     steps:
       - name: Checkout repository
         uses: actions/checkout@v3
+      - name: Set up QEMU
+        uses: docker/setup-qemu-action@v2
+        with:
+          platforms: 'arm64,arm'
       - name: Set up Docker Buildx
         uses: docker/setup-buildx-action@v2
       - name: Login to DockerHub
         uses: docker/login-action@v2
         with:
           username: {% raw %}${{ secrets.DOCKERHUB_USERNAME }}{% endraw %}
           password: {% raw %}${{ secrets.DOCKERHUB_TOKEN }}{% endraw %}
       - name: Build and push
         uses: docker/build-push-action@v3
         with:
           push: true
           tags: user/app:latest
\ No newline at end of file
```

> NOTE: you must add the `QEMU` step before the `buildx` step. 
> By default `QEMU` will create almost a dozen vm's. You'll want to limit it to just the architectures you care about.

## Architecture Specific Dockerfile Instructions

Depending on the content of your Dockerfile, at this point you may be done. 
The `setup-qemu-action` will create 2 (or more) VMs, and the `build-push-action` will 
compile your Dockerfile for various architectures, and push them to `Docker Hub` (within the same manifest).

However, if you need to conditionalize your Dockerfile instructions depending on which architecture you're building,
you'll need to make some additional changes. 

Under the hood, the `build-push-action` will provide the `--platform` flag to `docker buildx`. 
This will [automatically set](https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope) the following build `ARG`s:

- `TARGETPLATFORM` - platform of the build result. Eg `linux/amd64`, `linux/arm/v7`, `windows/amd64`.
- `TARGETOS` - OS component of `TARGETPLATFORM`
- `TARGETARCH` - architecture component of `TARGETPLATFORM`
- `TARGETVARIANT` - variant component of `TARGETPLATFORM`
- `BUILDPLATFORM` - platform of the node performing the build.
- `BUILDOS` - OS component of `BUILDPLATFORM`
- `BUILDARCH` - architecture component of `BUILDPLATFORM`
- `BUILDVARIANT` - variant component of `BUILDPLATFORM`

To use these variables to conditionally download arch specific dependencies, you can modify your Dockerfile like so:

```dockerfile
FROM debian:bullseye-slim
ARG TARGETARCH

RUN apt-get update && apt-get install -y curl \
    &&  case ${TARGETARCH} in \
            "amd64")  S6_ARCH=amd64  ;; \
            "arm64")  S6_ARCH=aarch64  ;; \
        esac \
    && curl https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-${S6_ARCH}.tar.gz -L -s --output /tmp/s6-overlay-${S6_ARCH}.tar.gz \
    && curl -L https://dl.influxdata.com/influxdb/releases/influxdb2-2.2.0-${TARGETARCH}.deb --output /tmp/influxdb2-2.2.0-${TARGETARCH}.deb \
    && ....
```

## Troubleshooting

### Q: I enabled Multi-arch builds and my builds take 1h+, what gives?
**A:** This seems to be a [known issue with `QEMU`](https://github.com/docker/setup-qemu-action/issues/22).
I've also run into this with NPM installs and TypeScript compilation. 
My workaround was to move non-architecture specific compilation before the Docker build & QEMU steps.
This means the steps are running outside the VMs and my build time dropped down to ~15 minutes, which is much more reasonable. 


# References
- https://docs.docker.com/desktop/multi-arch/
- https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/
- https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
- https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/
- https://github.com/BretFisher/multi-platform-docker-build