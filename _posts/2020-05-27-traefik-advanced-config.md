---
layout: post
title: Traefik v2 - Advanced Configuration
date: '2020-05-27T22:37:09-07:00'
cover: '/assets/images/cover_traefik_docker.png'
subclass: 'post tag-post'
tags:
- devops
- docker
- traefik
categories: 'analogj'
logo: '/assets/logo-dark.png'
navigation: False
toc: true
hidden: true
---

> Traefik is the leading open source reverse proxy and load balancer for HTTP and TCP-based applications that is easy,
> dynamic, automatic, fast, full-featured, production proven, provides metrics, and integrates with every major cluster technology
>       https://containo.us/traefik/

Still not sure what Traefik is? Basically it's a load balancer & reverse proxy that integrates with docker/kubernetes to automatically
route requests to your containers, with very little configuration.

The release of Traefik v2, while adding tons of features, also completely threw away backwards compatibility, meaning that
 the documentation and guides you can find on the internet are basically useless.
It doesn't help that the auto-magic configuration only works for toy examples. To do anything real requires real configuration.

This guide assumes you're somewhat familiar with Traefik, and you're interested in adding some of the advanced features mentioned in the Table of Contents.

## Requirements






## Subdomains





## WebUI Dashboard

## Limit to Network

## LetsEncrypt Integration
## Global HTTP -> HTTPS redirect
## 2FA/SAML/SSO

