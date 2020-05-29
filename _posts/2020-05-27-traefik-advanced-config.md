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


## Base Traefik Docker-Compose

Before we start working with the advanced features of Traefik, lets get a simple example working.
We'll use this example as the base for any changes necessary to enable an advanced Traefik feature.

- First, we need to create a shared Docker overlay network. Docker Compose (which we'll be using in the following examples) will create your container(s)
but it will also create a docker overlay network speficially for containers defined in the compose file. This is fine until
you notice that traefik is unable to route to containers defined in other `docker-compose.yml` files, or started manually via `docker run`
To solve this, we'll need to create a shared docker overlay network using `docker network create traefik` first.

- Next, lets create a new folder and a `docker-compose.yml` file. In the subsequent examples, all differences from this config will be bolded.
    ```yaml
version: '2'
services:
  traefik:
    image: traefik:v2.0
    ports:
      # The HTTP port
      - "80:80"
    volumes:
      # For Traefik's automated config to work, the docker socket needs to be mounted.
      # There are some security implications to this. See https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
      # and https://docs.traefik.io/providers/docker/#docker-api-access
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    command:
      - --providers.docker
      - --entrypoints.web.address=:80
      - --providers.docker.network=traefik
    networks:
      - traefik

# Use our previously created `traefik` docker network, so that we can route to containers that are created in
# external docker-compose files and manually via `docker run`
networks:
  traefik:
    external: true
    ```

## WebUI Dashboard

First, lets start by enabling the built in Traefik dashboard. This dashboard is useful for debugging as we enable other
advanced features, however you'll want to ensure that it's disabled in production.

<pre><code class="yaml">
version: '2'
services:
  traefik:
    image: traefik:v2.0
    ports:
      - "80:80"
      <b># The Web UI (enabled by --api.insecure=true)</b>
      <b>- "8080:8080"</b>
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    command:
      - --providers.docker
      - --entrypoints.web.address=:80
      - --providers.docker.network=traefik
      <b>- --api.insecure=true</b>
    labels:
      <b>- 'traefik.http.routers.traefik.rule=Host(`traefik.example.com`)'</b>
      <b>- 'traefik.http.routers.traefik.service=api@internal'</b>
    networks:
      - traefik
networks:
  traefik:
    external: true
</code></pre>

In a browser, just open up `http://traefik.example.com` or the domain name you specified in the `traefik.http.routers.traefik.rule` label.
You should see the following dashboard:

<img src="{{ site.url }}/assets/images/traefik/traefik-dashboard.png" alt="traefik dashboard" style="max-height: 500px;"/>


## Automatic Subdomain Routing

One of the most useful things about Traefik is its ability to dynamically route traffic to containers.
Rather than have to explicitly assign a domain or subdomain for each container, you can tell Traefik to use the container name
(or service name in a docker-compose file) prepended to a domain name for dynamic routing. eg. `container_name.example.com`

<pre><code class="yaml">
version: '2'
services:
  traefik:
    image: traefik:v2.0
    ports:
      - "80:80"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    command:
      - --providers.docker
      - --entrypoints.web.address=:80
      - --providers.docker.network=traefik
      <b>- '--providers.docker.defaultRule=Host(`{{ normalize .Name }}.example.com`)'</b>
    networks:
      - traefik
networks:
  traefik:
    external: true
</code></pre>

Next, lets start up a Docker container running the actual server that we want to route to.

```bash

docker run \
    --rm \
    --label 'traefik.http.services.foo.loadbalancer.server.port=80' \
    --name 'foo' \
    --network=traefik \
    tutum/hello-world

```

Whenever a container starts Traefik will interpolate the `defaultRule` and configure a router for this container.
In this example, we've specified that the container name is `foo`, so the container will be accessible at
`foo.example.com`

> Note: if your service is running in another docker-compose file, `{{ normalize .Name }}` will be interpolated as: `service_name-folder_name`,
> so your container will be accessible at `service_name-folder_name.example.com`

### Override Subdomain Routing using Container Labels



## Restrict Scope
By default Traefik will watch for all containers running on the Docker daemon, and attempt to automatically configure routes and services for each.
If you'd like a litte more control, you can pass the `--providers.docker.exposedByDefault=false` CMD argument to the Traefik container and selectively
enable routing for your containers by adding a `traefik.enable=true` label.


<pre><code class="yaml">
version: '2'
services:
  traefik:
    image: traefik:v2.0
    ports:
      - "80:80"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    command:
      - --providers.docker
      - --entrypoints.web.address=:80
      - --providers.docker.network=traefik
      - '--providers.docker.defaultRule=Host(`{{ normalize .Name }}.example.com`)'
      <b>- '--providers.docker.exposedByDefault=false'</b>
    networks:
      - traefik

  hellosvc:
    image: tutum/hello-world
    labels:
      <b>- traefik.enable=true</b>
    networks:
      - traefik
networks:
  traefik:
    external: true
</code></pre>

As I mentioned earlier, `normalize .Name` will be interpolated as `service_name-folder_name` for containers started via docker-compose.
So my Hello-World test container will be accessible as `hellosvc-tmp.example.com` on my local machine.

## LetsEncrypt Integration


## Global HTTP -> HTTPS redirect
## 2FA/SAML/SSO



