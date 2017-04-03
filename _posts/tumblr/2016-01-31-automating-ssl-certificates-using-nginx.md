---
layout: post
title: Automating SSL Certificates using Nginx & Letsencrypt - Without the Catch 22
date: '2016-01-31T21:49:09-08:00'
cover: 'assets/images/cover_letsencrypt.jpg'
subclass: 'post tag-fiction'
tags:
- letsencrypt
- docker
- automation
- SSL
- nginx
tumblr_url: http://blog.thesparktree.com/post/138452017979/automating-ssl-certificates-using-nginx
categories: 'analogj'
navigation: True
---
There's a ton of smart people out there who've written guides on [setting](https://sysops.forlaravel.com/letsencrypt) [up](https://blog.rudeotter.com/lets-encrypt-ssl-certificate-nginx-ubuntu/) [Nginx](https://davidzych.com/setting-up-ssl-with-lets-encrypt-on-ubuntu-and-nginx/), [and](https://community.letsencrypt.org/t/howto-easy-cert-generation-and-renewal-with-nginx/3491/2) [automating](https://adambard.com/blog/using-letsencrypt-with-nginx/) [Letsencrypt](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-14-04) —but none that setup automation and work 100% correctly out of the box. That’s the goal here, I’ll be documenting all the steps required to get your web application protected by an automatically renewing SSL certificate.

> NOTE: The following commands will require root user permissions.
> You might want to run `sudo su -` first.

## Installing Nginx

The first step is to install Nginx. If all you want to do is install the standard version, it should be available via your distro’s package manager.

```bash
# install Nginx on Ubuntu
apt-get update
apt-get install -y nginx
```

## Install Letsencrypt.sh

The second step is to install a Letsencrypt client. The [official client](https://github.com/letsencrypt/letsencrypt) is a bit bloated and complicated to setup. I prefer to use the [letsencrypt.sh client](https://github.com/lukas2511/letsencrypt.sh) instead as its code is easier to understand, has few dependencies and its incredibly simple to automate.

```bash
# install letsencrypt.sh dependencies (most should already be installed)
apt-get install -y openssl curl sed grep mktemp git

# install letsencrypt.sh into /srv/letsencrypt
git clone https://github.com/lukas2511/letsencrypt.sh.git /srv/letsencrypt
```

## Configure Letsencrypt

Letsencrypt.sh requires some configuration, but not much, the defaults work out of the box. That means that all you need to do is

- create a domains.txt file with the url(s) of the site(s) you’re generating ssl certificates for
- create a acme-challenges folder that can be  accessed by Nginx.

Here's how we can do that.

```bash
# First we need to make the client executable
chmod +x /srv/letsencrypt/letsencrypt.sh
# Then we need to create an ACME challenges folder and symlink it for Nginx to use
mkdir -p /srv/letsencrypt/.acme-challenges
mkdir -p /var/www/
ln -s /srv/letsencrypt/.acme-challenges /var/www/letsencrypt
 ```

Finally we need to specify the site(s) that will be protected by Letsencrypt ssl certificates.

    echo "www.example.com" >> /srv/letsencrypt/domains.txt

Read more about the domains.txt file format [here](https://github.com/lukas2511/letsencrypt.sh#domainstxt)

## Configure Nginx (without the Catch-22)

Up to now, the steps I’ve shown have been the same as almost any other Letsencrypt+Nginx guide you’ve seen online. However most of other guides will tell you to configure Nginx in a way that requires manual intervention.

A basic Letsencrypt Nginx configuration file looks like this:

```
# DONT USE THIS, IT WONT WORK.

# /etc/nginx/sites-enabled/example.conf
# HTTP server
server {
	listen      80;
	server_name www.example.com;
	location '/.well-known/acme-challenge' {
		default_type "text/plain";
		alias /var/www/letsencrypt;
	}
	location / {
		return 301 https://$server_name$request_uri;
	}
}
# HTTPS
server {
	listen       443;
	server_name  www.example.com;
	ssl                  on;
	ssl_certificate      /srv/letsencrypt/certs/www.example.com/fullchain.pem;
	ssl_certificate_key  /srv/letsencrypt/certs/www.example.com/privkey.pem;

	...
}
```

There’s a problem with this though. If you try starting up your Nginx server with this config, it’ll throw an error because the SSL certificate files don't exist. And you can’t start the letencrypt.sh command to generate the SSL certificates without a working Nginx server to serve up the acme-challenge folder. Classic catch 22.

Here’s the solution: we’re going to break up the Nginx configuration into 2 separate configuration files, one for the  HTTP endpoint with letsencrypt challenge files and one for the HTTPS endpoint serving the actual web application.

We’ll then place them both in the `sites-available` folder rather than the standard `sites-enabled` folder. By default, any configuration files in the `sites-enabled` folder are automatically parsed by Nginx when it’s restarted, however we want to control this process.

The HTTP Nginx configuration file will be located at: `/etc/nginx/sites-available/http.example.conf` and look like:

```
# HTTP server
server {
	listen      80;
	server_name www.example.com;
	location '/.well-known/acme-challenge' {
		default_type "text/plain";
		alias /var/www/letsencrypt;
	}
	location / {
		return 301 https://$server_name$request_uri;
	}
}
```

The HTTPS Nginx configuration file will be located at `/etc/nginx/sites-available/https.example.conf` and look like:

```
# HTTPS
server {
	listen       443;
	server_name  www.example.com;
	ssl                  on;
	ssl_certificate      /srv/letsencrypt/certs/www.example.com/fullchain.pem;
	ssl_certificate_key  /srv/letsencrypt/certs/www.example.com/privkey.pem;

	#Include actual web application configuration here.
}
```

## Controlling Nginx

Before we do anything else, we’ll need to first stop the running Nginx service.

    service nginx stop

Then we need to enable the HTTP endpoint by creating a symlink from the `sites-available` file to the `sites-enabled` folder, and starting the Nginx service

```bash
echo "Enable the http endpoint"
ln -s /etc/nginx/sites-available/http.example.conf /etc/nginx/sites-enabled/http.example.conf

echo "Starting nginx service..."
service nginx start
```

At this point we have a working HTTP endpoint which will correctly serve up any files in the `acme-challenge` folder. Lets generate some certificates.

```bash
echo "Generate Letsencrypt SSL certificates"
/srv/letsencrypt/letsencrypt.sh --cron
```

After the certificates are generated successfully by Letsencrypt.sh, we’ll have to enable our HTTPS endpoint, which is where all standard traffic is being redirected to.

```bash
echo "Enable the https endpoint"
ln -s /etc/nginx/sites-available/https.example.conf /etc/nginx/sites-enabled/https.example.conf
```

Finally, we need to tell Nginx update its configuration, as we've just added the HTTPS endpoint, but we want to do it without any downtime. Thankfully the Nginx developers have provided us a way to do that.

```bash
echo "Reload nginx service..."
service nginx reload
```

Now we have a working HTTPS enabled web application. The only thing left to do is automate the certificate renewal.

## Downtime-Free Automatic Certificate Renewal

Automatically renewing your SSL certificate isn’t just a cool feature of Letsencrypt.sh, its actually almost a requirement. By default Letsencrypt certificates expire every 90 days, so renewing it manually would pretty annoying. Thankfully it only takes a single command to completely automate this process.

```bash
echo "Register Letsencrypt to run weekly"
echo "5 8 * * 7 root /srv/letsencrypt/letsencrypt.sh --cron && service nginx reload" > /etc/cron.d/letsencrypt.sh
chmod u+x  /etc/cron.d/letsencrypt.sh
```

That command will register a new cron task to run every week that will run the letsencrypt.sh command. If the letsencrypt.sh script detects that the certificate will expire within 30 days, the certificates will be renewed automatically, and the Nginx server will reload, without any downtime.

## Fin

At this point you should have a working SSL protected web application, with automatic certificate renewal, at the cost of a handful of bash commands.

If you’re looking for an example of how this process can be used to automatically protect a website running inside a Docker container, look no further than my minimal [letsencrypt-http01-docker-nginx-example](https://github.com/AnalogJ/letsencrypt-http01-docker-nginx-example) repo.

If you would like to see a more real world use of Letsencrypt with Nginx and automation you should check my [Gitmask](https://github.com/AnalogJ/gitmask) repo.