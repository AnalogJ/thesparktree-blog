---
layout: post
title: 'A Complete Guide to Dockerfiles'
date: '21-08-17T01:19:33-08:00'
cover: '/assets/images/cover_docker.png'
subclass: 'post tag-post'
tags:
- docker
- dockerfile
- automation

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
toc: true
---


I write a lot of Dockerfiles. I do it professionally, as much of the software I maintain leverages Docker in some way.
But even I sometimes have a hard time remembering the minutia of the countless guides, tutorials and "best practices" articles
I've read related to Dockerfiles. This post is my attempt at writing a comprehensive guide to writing & building Dockerfiles
securely at scale.

This guide will be broken into the following sections:

- Writing Dockerfiles
- Building Dockerfiles
- Testing
- Building at Scale
- Secrets & Security
- Metadata


There will be some overlap between sections, as some functionality (like Multistage builds) can be leveraged to solve multiple problems.

---

## Writing Dockerfiles

I'll be making an assumption that you're already familiar with the basics of Docker and Dockerfiles.

### References

Some of the "best practices" that I'll be discussing are novel, but some I picked up from other tutorials, guides & even the official documentation.
I've called them out below. They're all related to writing Dockerfiles (I have a separate section for references related to building Dockerfiles).

- https://docs.docker.com/engine/reference/builder/
- https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- https://www.docker.com/blog/intro-guide-to-dockerfile-best-practices/
- https://pythonspeed.com/articles/system-packages-docker/

### FROM Instruction - Picking a Base Image

This may be obvious, but the base image you choose has a significant impact on the size, security & maintainability of your image.

When choosing a base image, I recommend that you prioritize based on the following list:

1. **Multistage** - Determine if you can break your Dockerfile into multiple stage, with different base images (Build vs Runtime, etc.)
1. **Mandated** - Large corporations will have official pre-hardened & maintained base images. If possible, let some other team do the hard work for you.
1. **Official** - If you don't have an internal team hardening your images, then find *official* images that are kept up-to-date, and patched. Look for images that are constantly being built & updated, by the actual developer (or a recognizable organization)
1. **Maintained** - If you can't find a pre-built base image with the software you need, fall back to maintained/hardened OS images.
1. **Slim** - Only start optimizing for size once you have multiple maintained, secure images to choose from. Most distros offer multiple flavors, including slim images with limited tooling & pre-installed packages.

### RUN Instruction - Package Managers


Unfortunately, the default options for system package installation with Debian, Ubuntu, CentOS, and RHEL can result in much bigger images than you actually need.


### Merge Instructions - Limiting Layers
< TODO >

### Build Context & `.dockerignore`
< TODO >

### Multistage Builds
< TODO >

## Building Dockerfiles

### Caching
< TODO >

### Instruction Ordering
< TODO >

### Cache Busting
< TODO >

## Testing
< TODO >

## Building at Scale

### Base Images - Docker Hub Mirror

> As of November 1, 2020, Docker Hub has implemented the following rate limits that apply to unauthenticated or authenticated pull requests.
> Free plan – anonymous users: 100 pulls per 6 hours
> Free plan – authenticated users: 200 pulls per 6 hours
> Pro plan – 50,000 pulls in a 24 hour period
> Team plan – 50,000 pulls in a 24 hour period

While it's hard to judge a company that has provided such an valuable free service for so long, it's a significant departure from their existing business model, and
poses challenges to users & companies that build images at scale.

- **Artifact Repository Mirror** - If your company uses a artifact repository like Nexus or Artifactory, you can setup a "pull-through cache" mirror.
- **Internal Mirror** - You can also spin up your own Docker Registry pull-through mirror, based on the [Official Docker Registry Image](https://docs.docker.com/registry/recipes/mirror/)
- **Public Mirror** - Google GCP (& some others) provide a [public mirror](https://cloud.google.com/container-registry/docs/pulling-cached-images) that you can use as a fallback if you get rate limited by Docker Hub.


To avoid disruptions and have greater control over your software supply chain, you can migrate your dependencies to Container Registry or Artifact Registry.


### Build Engines
< TODO > (Kaniko, Buildah)


## Secrets & Security

### Buildkit
< TODO >

### Hardening Guide
< TODO >
### Multistage Builds
< TODO >

## Metadata
< TODO >


