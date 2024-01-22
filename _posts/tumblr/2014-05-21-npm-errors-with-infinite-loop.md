---
layout: post
title: npm errors with infinite loop
date: '2014-05-21T14:35:02-07:00'
cover: '/assets/images/cover_npm.png'
subclass: 'post tag-post'
tags:
- npm
- nodejs
redirect_from:
- /post/86424236989/npm-errors-with-infinite-loop
- /post/86424236989
disqus_id: 'https://blog.thesparktree.com/post/86424236989'
categories: 'analogj'
navigation: True
logo: '/assets/logo-dark.png'
---
Occasionally I’ll be working with a nodejs project and when I attempt to run `$ npm install` I’ll see what appears to be an infinite loop with the same package partially installing and then failing over and over.

I found a fix on the npm github issue tracker and I’ve added it here for posterity

`rm -rf ~/.npm`
