---
layout: post
title: Javascript Document.Write
date: '2011-09-21T00:00:00-07:00'
cover: 'assets/images/cover_javascript.jpg'
subclass: 'post tag-fiction'
tags:
- Javascript Antipattern
tumblr_url: http://blog.thesparktree.com/post/41985959910/javascript-documentwrite
categories: 'analogj'
navigation: True
---
document write is an antipattern,

use:

```javascript
function elemTest() {
    var newDiv = document.createElement("div");
    newDiv.innerHTML = "<h1>Hi there!</h1>";
    document.body.appendChild(newDiv);
};
```