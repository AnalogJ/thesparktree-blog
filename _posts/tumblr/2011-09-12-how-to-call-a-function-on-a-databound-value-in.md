---
layout: post
title: How to call a function on a databound value in ListView
date: '2011-09-12T00:00:00-07:00'
cover: 'assets/images/cover_visual_studio.png'
subclass: 'post tag-fiction'
tags:
- ASP.Net
- C
tumblr_url: http://blog.thesparktree.com/post/41986292128/how-to-call-a-function-on-a-databound-value-in
categories: 'analogj'
navigation: True
---
Wrap your Eval call:

Markup:
    <asp:LinkButton id="whatever" runat="server"
     Visible=''<%# ShowHideLink(Eval("Storage")) %>

Code-Behind:

```cs
protected bool ShowHideLink(object obj)
{
bool result = false;
//cast obj to whatever datatype it is
int numOfProducts = (int)obj;

//do some evaluating
if(numOfProducts &gt; 10) //whatever your biz logic is
{
    result = true;
}

return result;
}
```

reference: http://stackoverflow.com/questions/1530704/how-to-use-evalx-value-in-listview
