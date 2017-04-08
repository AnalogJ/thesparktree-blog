---
layout: post
title: Local Development with Wildcard DNS
date: '2017-04-07T01:19:33-08:00'
cover: '/assets/images/cover_localhost.png'
subclass: 'post tag-post'
tags:
- dns
- dnsmasq
- macOS
- docker
navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

The holy-grail of local development is wildcard DNS: the ability to have `*.local.company.com` pointing to `localhost`, your development machine.
It doesn't matter if you're working on `website.local.company.com` or `api.local.company.com`, there's no additional configuration necessary as you start working on new projects.

Unfortunately macOS doesn't support wildcard entries in the `/etc/hosts` file -- no OS does out of the box.

## Dnsmasq

[Dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) is a tiny and incredibly popular DNS server that you can run locally, and supports wildcard domain resolution with very little configuration.

```bash
brew install dnsmasq
```

Now lets setup the configuration directory and configure `dnsmasq` to resolve all of our development domains. 

> You'll want to avoid the `*.dev` and `*.local` domains for development. `.dev` exists as a real [TLD in the ICANN root](https://newgtlds.icann.org/en/program-status/delegated-strings). `.local` is used by the [Bonjour service](https://support.apple.com/en-us/HT201275) on macOS. I recommend using `*.local.companyname.com` or `*.lan`

```bash
mkdir -pv $(brew --prefix)/etc/

cat >$(brew --prefix)/etc/dnsmasq.conf <<EOL

# Add domains which you want to force to an IP address here.
# The example below send any host in *.local.company.com and *.lan to a local
# webserver.
address=/local.company.com/127.0.0.1
address=/lan/127.0.0.1

# Don't read /etc/resolv.conf or any other configuration files.
no-resolv
# Never forward plain names (without a dot or domain part)
domain-needed
# Never forward addresses in the non-routed address spaces.
bogus-priv

EOL
```

Then lets configure `launchd` start `dnsmasq` now and restart at startup:

```bash
sudo brew services start dnsmasq
```

Finally lets validate that our `dnsmasq` server is configured to respond to all subdomains of `local.company.com` by running:

```bash
$ dig nested.test.local.company.com @127.0.0.1

; <<>> DiG 9.8.3-P1 <<>> nested.test.local.company.com @127.0.0.1
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 64864
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;nested.test.local.company.com.	IN	A

;; ANSWER SECTION:
nested.test.local.company.com. 0 IN	A	127.0.0.1

;; Query time: 0 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Sat Apr  8 11:15:17 2017
;; MSG SIZE  rcvd: 63
```


## Integration using `/etc/resolver`

At this point we have a working DNS server, but it's meaningless because macOS won't use it for resolving any domains. 

We can change this by adding configuration files in the `/etc/resolver` directory.

```bash
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/local.company.com'
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/lan'
```

Each domain that we configured in `dnsmasq` should have a corresponding entry in `/etc/resolver/` 

Next, lets test that our resolver entries have been picked up by macOS. 

```bash
$ scutil --dns

...
resolver #8
  domain   : local.company.com
  nameserver[0] : 127.0.0.1
  flags    : Request A records
Reachable, Directly Reachable Address
...
```

## Fin

Testing you new configuration is easy; just use ping check that you can now resolve your local subdomains:

```bash
# Make sure you haven't broken your DNS.
ping -c 1 www.google.com

# Check that .local.company.com & .lan names work
ping -c 1 this.is.a.test.local.company.com
ping -c 1 this.domain.does.not.exist.lan
```

This is useful in particular for developers of microservices: your orchestration platform can dynamically generate hostnames, and you won't have to worry about your `/etc/hosts` file again. 


### References
- http://asciithoughts.com/posts/2014/02/23/setting-up-a-wildcard-dns-domain-on-mac-os-x/
- https://gist.github.com/eloypnd/5efc3b590e7c738630fdcf0c10b68072
- https://passingcuriosity.com/2013/dnsmasq-dev-osx/
- http://serverfault.com/questions/118378/in-my-etc-hosts-file-on-linux-osx-how-do-i-do-a-wildcard-subdomain
- https://gist.github.com/ogrrd/5831371