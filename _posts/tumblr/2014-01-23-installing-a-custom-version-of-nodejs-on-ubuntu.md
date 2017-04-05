---
layout: post
title: Installing a custom version of NodeJS on Ubuntu 13.10
date: '2014-01-23T13:27:00-08:00'
cover: '/assets/images/cover_ubuntu.png'
subclass: 'post tag-post'
tags:
- nodejs
- node
- ubuntu
redirect_from: /post/74294778727/installing-a-custom-version-of-nodejs-on-ubuntu
disqus_id: 'http://blog.thesparktree.com/post/74294778727'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---
The following is the quickest way to install nodejs latest and specific versions node.js on Ubuntu. According to the nodejs [official gists](https://gist.github.com/isaacs/579814), there are a few other ways to install node.js, and you can check out the other possibilities if you prefer.

```bash
# Adding yourself to the group to access /usr/local/bin
ME=$(whoami) ; sudo chown -R $ME /usr/local && cd /usr/local/bin

mkdir _node && cd $_ && wget http://nodejs.org/dist/v0.10.24/node-v0.10.24-linux-x64.tar.gz -O - | tar zxf - --strip-components=1

# Making the symbolic link to node
ln -s "/usr/local/bin/_node/bin/node" ..
# Making the symbolic link to npm
ln -s "/usr/local/bin/_node/lib/node_modules/npm/bin/npm-cli.js" ../npm
```

You can replace the `v.0.11.10` in the script above with any version from the list of [all nodejs versions](http://nodejs.org/dist/)

If you just wanted the official latest release you can also do:

```bash
sudo apt-get install python-software-properties python g++ make
sudo add-apt-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install nodejs
```