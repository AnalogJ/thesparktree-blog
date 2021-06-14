---
layout: post
title: 'OpenLDAP using STARTTLS & LetsEncrypt'
date: '21-06-13T01:19:33-08:00'
cover: '/assets/images/cover_ldap.png'
subclass: 'post tag-post'
tags:
- ldap
- letsencrypt
- tls

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

> LDAP (Lightweight Directory Access Protocol) is an open and cross platform protocol used for directory services authentication.
>
> LDAP provides the communication language that applications use to
> communicate with other directory services servers. Directory services
> store the users, passwords, and computer accounts, and share that
> information with other entities on the network.
>
> **OpenLDAP** is a [free](https://en.wikipedia.org/wiki/Free_software),
> [open-source](https://en.wikipedia.org/wiki/Open-source_software "Open-source software") implementation of the
> [Lightweight Directory Access Protocol](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol "Lightweight Directory Access Protocol")
> (LDAP) developed by the OpenLDAP Project. It is released under its own BSD-style license called the OpenLDAP Public License.[[4]](https://en.wikipedia.org/wiki/OpenLDAP#cite_note-4)

There are 2 commonly used mechanisms to secure LDAP traffic - LDAPS and StartTLS. LDAPS is deprecated in favor of Start TLS [RFC2830].

During some recent infrastructure changes I found out the hard way that [LDAP plugin for Jenkins does not support LDAP over TLS (StartTLS)](https://issues.jenkins.io/browse/JENKINS-14520).
Given that LDAPS is officially deprecated, I began work on a PR to add StartTLS support myself.

Before I could start coding, I needed to create a local development environment with an LDAP server speaking StartTLS.
Unfortunately, this was harder than I anticipated, as StartTLS (while officially supported since LDAPv3) is not well documented.

In the following post ,I'll show you how to get OpenLDAP up and running with StartTLS, using valid certificates from LetsEncrypt.

As always, the code is Open Source and lives on Github:

<div class="github-widget" data-repo="AnalogJ/docker-openldap-starttls"></div>



# Self-Signed vs Trusted CA Certificates

There are two types of **SSL Certificates** when you’re talking about signing. There are **Self-Signed SSL Certificates** and certificates
that are signed by a Trusted Certificate Authority (and are usually already trusted by your system).

Most OpenLDAP documentation I was able to find used Self-Signed certifates. While that works fine for most development,
I am trying to replicate a production-like environment, which means real, trusted certificates. Thankfully, we can utilize
short-lived trusted certificates provided by LetsEncrypt to secure our test OpenLDAP server.

# Generate LetsEncrypt Certificate

<div class="github-widget" data-repo="matrix-org/docker-dehydrated"></div>

The [matrix.org](https://matrix.org/) team provide a simple [Docker image](https://github.com/matrix-org/docker-dehydrated#behaviour)
that you can use to generate LetsEncrypt certificates using the DNS-01 challenge. All you need is a custom domain, and a
[DNS provider with an API](https://github.com/AnalogJ/lexicon)

```bash
mkdir data

# We cannot use a wildcard domain with OpenLDAP, so let's pick a simple obvious subdomain.
echo "ldap.example.com" > data/domains.txt

docker run --rm \
-v `pwd`/data:/data \
-e DEHYDRATED_GENERATE_CONFIG=yes \
-e DEHYDRATED_CA="https://acme-v02.api.letsencrypt.org/directory" \
-e DEHYDRATED_CHALLENGE="dns-01" \
-e DEHYDRATED_KEYSIZE="4096" \
-e DEHYDRATED_HOOK="/usr/local/bin/lexicon-hook" \
-e DEHYDRATED_RENEW_DAYS="30" \
-e DEHYDRATED_KEY_RENEW="yes" \
-e DEHYDRATED_ACCEPT_TERMS=yes \
-e DEHYDRATED_EMAIL="myemail@gmail.com" \
-e PROVIDER=cloudflare \
-e LEXICON_CLOUDFLARE_USERNAME="mycloudflareusername" \
-e LEXICON_CLOUDFLARE_TOKEN="mycloudflaretoken" \
docker.io/matrixdotorg/dehydrated
```

> NOTE: pay attention to those last 3 environmental variables. They are passed to [lexicon](https://github.com/AnalogJ/lexicon)
> and should be changed to match your DNS provider.



Once `dehydrated` prints its success messge , you should see a handful of new subfolders in `data`:

```
data
├── accounts
│ └── xxxxxxxxxxxxxx
│     ├── account_id.json
│     ├── account_key.pem
│     └── registration_info.json
├── certs
│ └── ldap.example.com
│     ├── cert-xxxxxx.csr
│     ├── cert-xxxxxx.pem
│     ├── cert.csr -> cert-xxxxxx.csr
│     ├── cert.pem -> cert-xxxxxx.pem
│     ├── chain-xxxxxx.pem
│     ├── chain.pem -> chain-xxxxxx.pem
│     ├── combined.pem
│     ├── fullchain-xxxxxx.pem
│     ├── fullchain.pem -> fullchain-xxxxxx.pem
│     ├── privkey-xxxxxx.pem
│     └── privkey.pem -> privkey-xxxxxx.pem
├── chains
├── config
└── domains.txt
```

Let's leave these files alone for now, and continue to standing up and configuring our OpenLDAP server.


# Deploying OpenLDAP via Docker

Since we're not actually deploying a production instance (with HA/monitoring/security hardening/etc) we can take
some short-cuts and use an off-the-shelf Docker image.

<div class="github-widget" data-repo="AnalogJ/docker-openldap-starttls"></div>

The [analogj/docker-openldap-starttls](https://github.com/AnalogJ/docker-openldap-starttls) image we're using in the
example below is based on the  [rroemhild/test-openldap](https://github.com/rroemhild/docker-test-openldap/) Docker image,
 which provies a vanilla install of OpenLDAP, and adds Futurama characters as test users.

I've customized it to add support for custom Domains, dynamic configuration & the ability to enforce StartTLS on the
serverside (which is great for testing).

Before we start the OpenLDAP container, lets rename and re-organize our LetsEncrypt certificates in a folder structure that the container expects:

```
mkdir -p ldap
cp data/fullchain.pem ldap/fullchain.crt
cp data/cert.pem ldap/ldap.crt
cp data/privkey.pem ldap/ldap.key
```



Next, lets start the OpenLDAP Docker container:

```
docker run --rm \
-v `pwd`/ldap:/etc/ldap/ssl/ \
-p 10389:10389 \
-p 10636:10636 \
-e LDAP_DOMAIN="example.com" \
-e LDAP_BASEDN="dc=example,dc=com" \
-e LDAP_ORGANISATION="Custom Organization Name, Example Inc." \
-e LDAP_BINDDN="cn=admin,dc=example,dc=com" \
-e LDAP_FORCE_STARTTLS="true" \
ghcr.io/analogj/docker-openldap-starttls:master
```

> NOTE: the `LDAP_DOMAIN` should be your root domain (`example.com` vs `ldap.example.com` from your certificate).
> It's used for test user email addresses.
>
> Pay attention to the `LDAP_BASEDN` and `LDAP_BINDDN` variables, they should match your Domain root as well.
>
> `LDAP_FORCE_STARTTLS=true` is optional, you can use it to conditionally start your LDAP server with StartTLS enforced.



If everything is correct, you should see `slapd starting` as your last log message.



Lets test that the container is responding correctly, though the certificate will not match since we're going to query it
using `localhost:10389`

```bash
# LDAPTLS_REQCERT=never tells ldapsearch to skip certificate validation
# -Z is required if we used LDAP_FORCE_STARTTLS="true" to start the container.

LDAPTLS_REQCERT=never ldapsearch -H ldap://localhost:10389 -Z -x -b "ou=people,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w GoodNewsEveryone "(objectClass=inetOrgPerson)"

# ...
# search result
# search: 3
# result: 0 Success
#
# numResponses: 8
# numEntries: 7
```



# DNS

Wiring up DNS to correctly resolve to the new container running on you host is left as a exercise for the user.

For testing, I just setup a simple A record pointing `ldap.example.com` to my laptop's private IP address `192.168.0.123`.
It obviously won't resolve correctly outside my home network, but it works fine for testing.

```
$ ping ldap.example.com
PING ldap.example.com (192.168.0.123): 56 data bytes
64 bytes from 192.168.0.123: icmp_seq=0 ttl=64 time=0.045 ms
```

> NOTE: Remember, DNS updates can take a while to propagate. You'll want to set a low TTL for the new record if your IP will
> be changing constantly (DHCP). You may also need to flush your DNS cache if the changes do not propagate correctly.

# Testing

You can test that the container is up and running (and accessible via our custom domain) with some handy `ldapsearch` commands:

```
# List all Users (only works with LDAP_FORCE_STARTTLS=false)
ldapsearch -H ldap://ldap.example.com:10389 -x -b "ou=people,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w GoodNewsEveryone "(objectClass=inetOrgPerson)"

# Response:
# ldap_bind: Confidentiality required (13)
#	additional info: TLS confidentiality required

# Request StartTLS (works with LDAP_FORCE_STARTTLS=true/false)
ldapsearch -H ldap://ldap.example.com:10389 -Z -x -b "ou=people,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w GoodNewsEveryone "(objectClass=inetOrgPerson)"

# Enforce StartTLS (only works with LDAP_FORCE_STARTTLS=true)
ldapsearch -H ldap://example:10389 -ZZ -x -b "ou=people,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w GoodNewsEveryone "(objectClass=inetOrgPerson)"

# Query Open LDAP using Localhost url, also works with self-signed certs (-ZZ forces StartTLS)
LDAPTLS_REQCERT=never ldapsearch -H ldap://localhost:10389 -ZZ -x -b "ou=people,dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w GoodNewsEveryone "(objectClass=inetOrgPerson)"
```



# How does it work?

Other than my changes that allow you to customize the domain, there are only 2 main changes from [rroemhild's amazing work](https://github.com/rroemhild/docker-test-openldap/).

- A slightly modified `tls.ldif` file, which uses the fullchain, private key and certificate provided by LetsEncrypt

  ```
  dn: cn=config
  changetype: modify
  replace: olcTLSCACertificateFile
  olcTLSCACertificateFile: /etc/ldap/ssl/fullchain.crt
  -
  replace: olcTLSCertificateFile
  olcTLSCertificateFile: /etc/ldap/ssl/ldap.crt
  -
  replace: olcTLSCertificateKeyFile
  olcTLSCertificateKeyFile: /etc/ldap/ssl/ldap.key
  -
  replace: olcTLSVerifyClient
  olcTLSVerifyClient: never
  ```

- A new (conditionally loaded) `force-starttls.ldif` file, which tells OpenLDAP to force TLS

  ```
  dn: cn=config
  changetype:  modify
  add: olcSecurity
  olcSecurity: tls=1

  ```

# Fin

<div class="github-widget" data-repo="AnalogJ/docker-openldap-starttls"></div>

Getting all the details right took some time, but it was worth it. With this containerized setup, its easy to start
up a fresh "trusted" OpenLDAP image for testing, and conditionally enforce StartTLS.

Thankfully, I was able to use this local containerized OpenLDAP server to finish my work in the
[Jenkins LDAP-Plugin](https://github.com/jenkinsci/ldap-plugin/pull/97), which I'll be writing about in a future blog post.
