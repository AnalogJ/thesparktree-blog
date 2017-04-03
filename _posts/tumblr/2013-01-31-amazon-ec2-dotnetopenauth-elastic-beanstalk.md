---
layout: post
title: Amazon EC2 + DotNetOpenAuth + Elastic Beanstalk = Url Rewrite Hell (fix)
date: '2013-01-31T20:50:25-08:00'
cover: 'assets/images/cover_aws.jpg'
subclass: 'post tag-fiction'
tags: []
tumblr_url: http://blog.thesparktree.com/post/41988205995/amazon-ec2-dotnetopenauth-elastic-beanstalk
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'

---
This is the fix for the dotnetopenauth.aspnet module not working on an amazon ec2 instance that was published out using beanstalk. The web deploy folder + url rewriting rules that amazon places in the web config confuse the module and it dies. The following issue [https://github.com/DotNetOpenAuth/DotNetOpenAuth/issues/35](https://github.com/DotNetOpenAuth/DotNetOpenAuth/issues/35) in github references it, but no fix is avaliable at this time.

You can deploy your project to the root and then we won't put any IIS URL rewrite rules in the web.config. In Visual Studio right click on your project and select "Package/Publish Settings" and then in the field "IIS Web site/application name to use on the destination server:" change it from "Default Web Site/<yourapp>_deployed" to just "Default Web Site/".

By the way, questions about Visual Studio deployment are more likely to be answered faster in the AWS .NET Forums. https://forums.aws.amazon.com/forum.jspa?forumID=61

Hope that helps

Norm


from [https://forums.aws.amazon.com/thread.jspa?messageID=330957](https://forums.aws.amazon.com/thread.jspa?messageID=330957)