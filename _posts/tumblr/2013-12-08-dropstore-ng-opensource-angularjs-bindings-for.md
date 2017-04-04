---
layout: post
title: 'dropstore-ng: opensource AngularJS bindings for Dropbox Javascript API'
date: '2013-12-08T20:00:00-08:00'
cover: 'assets/images/cover_angularjs.png'
subclass: 'post tag-fiction'
tags:
- dropbox
- angularjs
- github
- javascript
redirect_from: /post/69434240145/dropstore-ng-opensource-angularjs-bindings-for
disqus_id: 'http://blog.thesparktree.com/post/69434240145'
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'

---
I created an github project called [dropstore-ng](https://github.com/AnalogJ/dropstore-ng) that has angularjs bindings for the recently released Dropbox Datastore API as well as all the other related functions in the Javascript API.
The service wraps most of the Dropbox Datastore callbacks in promises, contains subscription methods for Dropbox events and provides transparent aliases for untouched library methods.

I also created a realtime todo sample app which you can try [here](https://dropstore-ng.herokuapp.com/)

You can access the library here:
[https://github.com/AnalogJ/dropstore-ng](https://github.com/AnalogJ/dropstore-ng)

or through bower

```bash
bower install dropstore-ng --save
```

<div class="github-widget" data-repo="AnalogJ/dropstore-ng"></div>