---
layout: post
title: Custom Domains for AWS Lambda/API Gateway using Letsencrypt
date: '2016-11-08T12:41:19-08:00'
cover: 'assets/images/cover_letsencrypt.jpg'
subclass: 'post tag-post'

tags:
- letsencrypt
- lambda
- serverless
- lexicon
- aws
- devops
- apex
redirect_from: /post/152904762374/custom-domains-for-aws-lambdaapi-gateway-using
disqus_id: 'http://blog.thesparktree.com/post/152904762374'
navigation: True
logo: 'assets/logo.png'
categories: 'analogj'
navigation: True
---
> AWS Lambda lets you run code without provisioning or managing servers. You pay only for the compute time you consume - there is no charge when your code is not running.

In general Lambda is well designed and the platform is pretty developer friendly, especially if you use a framework like [serverless](https://github.com/serverless/serverless) or [apex](https://github.com/apex/apex). However as someone who creates new services on Lambda all the time, there is one thing that consistently annoys me.

**Configuring a custom domain for use with Lambda is stupidly complex for such a common feature.**

Here's the AWS documentation to [use a custom domain with API Gateway](http://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html). Take a look, I'll wait.

At first glance the instructions seem somewhat reasonable. For security reasons API Gateway requires SSL for all requests, which means that to use a custom domain, you first need an SSL certificate.

Unfortunately this becomes a problem when you realize that
Letsencrypt HTTP-01 doesn't work because of the catch-22 requiring you to prove that you own the custom domain before generating certificates. Even worse, AWS's built-in free certificate service (Certificate Manger) [doesn't yet support API Gateway](http://stackoverflow.com/questions/36497896/can-i-use-aws-certificate-manager-certificates-for-api-gateway-with-custom-domai).

So what's the solution?


---

I was able to create a nice little script using python which invokes the [aws-cli](https://aws.amazon.com/cli/), [dehydrated](https://github.com/lukas2511/dehydrated) letsencrypt client & [lexicon](https://github.com/AnalogJ/lexicon) and does all the steps necessary to add a custom domain to an API Gateway, automatically.

Here's what it does:

- validates that all the correct credentials & environmental variables are set
- validates that the specified AWS API Gateway exists
- generate a new set of letsencrypt certificates for the specified custom domain using the DNS-01 challenge & lexicon
- register custom domain name with AWS (which creates a distribution domain name on cloudfront)
- adds a CNAME dns record mapping your custom domain to the AWS distribution domain
- maps the custom domain to your selected API Gateway

The code is all open source and lives here: [Analogj/aws-api-gateway-letsencrypt](https://github.com/AnalogJ/aws-api-gateway-letsencrypt/blob/master/api-gateway-custom-domain.py)

<div class="github-widget" data-repo="AnalogJ/aws-api-gateway-letsencrypt"></div>

I've also created a simple [Docker image](https://github.com/AnalogJ/aws-api-gateway-letsencrypt/blob/master/Dockerfile) which you can use if you don't want to install anything:

```bash
docker run \
-e LEXICON_CLOUDFLARE_USERNAME=*** \
-e LEXICON_CLOUDFLARE_TOKEN=*** \
-e AWS_ACCESS_KEY_ID=*** \
-e AWS_SECRET_ACCESS_KEY=*** \
-e DOMAIN=api.quietthyme.com \
-e API_GATEWAY_NAME=dev-quietthyme-api \
-v `pwd`/certs:/srv/certs \
analogj/aws-api-gateway-letsencrypt
```