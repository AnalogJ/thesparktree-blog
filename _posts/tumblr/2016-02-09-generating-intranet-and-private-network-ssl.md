---
layout: post
title: Generating Intranet and Private Network SSL Certificates using LetsEncrypt
date: '2016-02-09T13:19:33-08:00'
cover: '/assets/images/cover_letsencrypt.jpg'
subclass: 'post tag-post'
tags:
- dns
- letsencrypt
- lexicon
- automation
- ssl
redirect_from: /post/138999997429/generating-intranet-and-private-network-ssl
disqus_id: 'http://blog.thesparktree.com/post/138999997429'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---
This post is a follow up to my previous one [Automating SSL Certificates using Nginx & LetsEncrypt](http://blog.thesparktree.com/post/138452017979/automating-ssl-certificates-using-nginx). This time we’ll be generating SSL certificates for intranet and non-public networks.

## Requirements
Before we get started, you’ll want to make sure that the following items are true.

- You must use a real/purchased domain. [Reserved domains/TLD’s](https://en.wikipedia.org/wiki/Top-level_domain#Reserved_domains) like `*.example`, `*.test`, `*.local` will never work.
- You must have an external DNS provider that has an API.
	- If your DNS provider doesn’t have an API, you can use [cloud flare.com](https://www.cloudflare.com) for free.
- You must have python 2.6+ installed

## Install Dehydrated

<div class="github-widget" data-repo="lukas2511/dehydrated"></div>

The first step is to install a Letsencrypt client. The [official client](https://github.com/letsencrypt/letsencrypt) is a bit bloated and complicated to setup. I prefer to use the [dehydrated client](https://github.com/lukas2511/dehydrated) instead as its code is easier to understand, has few dependencies and its incredibly simple to automate.

```bash
# install dehydrated dependencies (most should already be installed)
apt-get install -y openssl curl sed grep mktemp git

# install dehydrated into /srv/dehydrated
git clone https://github.com/lukas2511/dehydrated.git /srv/dehydrated
```

## Configure Dehydrated
Dehydrated requires some configuration, but not much, the defaults work out of the box. That means that all you need to do is

- create a domains.txt file with the url(s) of the site(s) you’re generating ssl certificates for

Here’s how we can do that.

```bash
# First we need to make the client executable
chmod +x /srv/dehydrated/dehydrated
# Then we need to specify the intranet/private domain
echo "test.intranet.example.com" > /srv/dehydrated/domains.txt
```

## Install Lexicon

<div class="github-widget" data-repo="AnalogJ/lexicon"></div>

Next we’re going to install the [Lexicon](https://github.com/AnalogJ/lexicon) library. Lexicon provides a way to manipulate DNS records on multiple DNS providers in a standardized way.

```bash
#  install python requests library dependencies
apt-get install -y build-essential python-dev curl libffi-dev libssl-dev
pip install requests[security]
pip install dns-lexicon
```

## Configure Lexicon
 The Lexicon library lets you automatically configure your DNS provider using Letsencrypt DNS challenges without having to deal with creating API calls yourself. Its perfect for generating internal/intranet SSL certs.

Dehydrated requires a hook file to complete `dns-01` challenges. The Lexicon repo has an example one that wires up the `deploy_challenge` and `clean_challenge` calls to Lexicon commands.

```bash
curl -O https://raw.githubusercontent.com/AnalogJ/lexicon/master/examples/dehydrated.default.sh /srv/dehydrated
chmod +x /srv/dehydrated/dehydrated.default.sh
```

The only information that Lexicon requires is:

- authentication information such as username/password or token.
  - In general your API token should be availble in your DNS provider's account settings page.
- provider name

We can pass all that information to Lexicon by setting a handful of environmental variables. If don’t want to do that, you can modify the hook file and add the `--auth-username` and `--auth-password` parameters to all `lexicon` commands.

```bash
#If our DNS provider is cloudflare
export PROVIDER=cloudflare
export LEXICON_CLOUDFLARE_USERNAME=username@example.com
export LEXICON_CLOUDFLARE_TOKEN=234dcef90c3d9aa0eb6798e16bdc1e4b
```

## Generate Certificates
Now that we’ve finished configuring everything, it’s time to generate the certificates. Its as simple as:

```bash
# Lets generate the Letsencrypt SSL certificates
/srv/dehydrated/dehydrated --cron --hook /srv/dehydrated/dehydrated.default.sh --challenge dns-01
```

Our certificates will be available in the following folder:

	/srv/dehydrated/certs/

## Fin
At this point we have working Letsencrypt SSL certificates for an internal/intranet domain that’s not accessible on the public internet.

I’ve written an example [Dockerfile](https://github.com/AnalogJ/lexicon/blob/master/Dockerfile) that you can reference if you’re curious. Just make sure to use `docker run -e "PROVIDER=cloudflare" -e ..` to set the environmental variables that you need.

If you’re wondering how to automate this whole process, check out my previous post: [Automating SSL Certificates using Nginx & LetsEncrypt](http://blog.thesparktree.com/post/138452017979/automating-ssl-certificates-using-nginx)