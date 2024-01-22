---
layout: post
title: Javascript Document.Write
date: '2011-09-21T00:00:00-07:00'
cover: '/assets/images/cover_javascript.jpg'
subclass: 'post tag-post'
tags:
- Javascript Antipattern
redirect_from:
- /post/41985959910/javascript-documentwrite
- /post/41985959910
disqus_id: 'https://blog.thesparktree.com/post/41985959910'
categories: 'analogj'
navigation: True
logo: '/assets/logo-dark.png'

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
