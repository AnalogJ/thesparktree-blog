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

- Docker
- A custom domain to assign to Traefik, or a [fake domain (.lan) configured for wildcard local development](https://blog.thesparktree.com/local-development-with-wildcard-dns)
- We'll be using the following traefik docker-compose file as the base for each of our examples. All differences from this
    config will be bolded.
    ```
      version: '2'
      services:
        traefik:
          image: traefik:v2.0
          ports:
            # The HTTP port
            - "80:80"
          volumes:
            - "/var/run/docker.sock:/var/run/docker.sock:ro"
          command:
            - --providers.docker
            - --entrypoints.web.address=:80
    ```




## Automatic Subdomain Routing

One of the most useful things about Traefik is its ability to dynamically route traffic to containers.
Rather than have to explicitly assign a domain or subdomain for each container, you can tell Traefik to use the container
name prepended to a domain name for dynamic routing. eg. `container_name.example.com`

<pre><code>
  version: '2'
  services:
    traefik:
      image: traefik:v2.0
      ports:
        # The HTTP port
        - "80:80"
      volumes:
        - "/var/run/docker.sock:/var/run/docker.sock:ro"
      command:
        - --providers.docker
        - --entrypoints.web.address=:80
        <b>- '--providers.docker.defaultRule=Host(`{{ normalize .Name }}.customsubdomain.example.com`)'</b>

</pre></code>




## WebUI Dashboard

## Limit to Network

## LetsEncrypt Integration
## Global HTTP -> HTTPS redirect
## 2FA/SAML/SSO

