---
layout: post
title: Devops for Startups & Small Teams
date: '2017-09-13T01:19:33-08:00'
cover: '/assets/images/cover_quietthyme.png'
subclass: 'post tag-post'
tags:
- devops
- startup
- teams
- startup
- automation
navigation: True
logo: '/assets/logo-dark.png'
categories: 'analogj'
---

Devops for Startups - It's not just a buzzword

When you're working on a side-project or at a startup as part of a small focused team, it can be hard to get away from 
the heads-down mentality of "just do it". But sometimes it can be valuable to step back and recognize that a bit of upfront 
infrastructure work can save you days or even weeks of time getting your MVP up and running. 

The following are the quick and dirty Devops patterns & procedures that I put in place before working on any new system. 
I primarily focus on free tools and services because of how cheap I am, so feel free to replace them comparable tools of your choice, 
you big spender, you.

# Before your first line
- Store your code in Git - Github [free open source]/Bitbucket [free private] - there shouldn't be more to say here other than, 
store your source in a VCS from day 1. 
- Design your app with multiple environments in mind. You should be able to switch between Local/Stage/Production development 
with no code changes, just configuration changes (environmental variables or a config file). 
- Isolate your configuration. Its probably not necessary to move your configuration into a compeltely separate system yet, 
but make sure you will be able to if you scale. Trying to do this after the fact is just begging for an application re-write. 
- Follow a branching pattern. At it's simplest it could just be 2 branches, "master" and "develop" or you could go nuts 
and follow gitflow. It doesn't matter, as long as you follow the damn thing, and don't just commit directly to master. 
This is going to be important later when you start doing Continuous Integration (CI). 
- Setup CI. You don't need to go full throttle with a standalone Jenkins server. Just make sure your code is compiling 
in a clean room environment, that doesn't include the dozens of apps and libraries you already have installed on your 
dev machine. TravisCI[free] and CircleCI [free] are great, and integrate with Github/Bitbucket. At a bare minimum build 
your artifacts in a Docker container.
- Setup an issue tracker, project management board. Waffle.io [free] is great and integrates with Github, but you may be 
able to just get away with Github projects [free] to start
- Make some Architecture decisions:
	- Decide if you can get away with a static frontend or SPA architecture for your front end. If you can, you'll get 
	infinite scaling of your front-end for almost free. Distributing static files is a solved problem--CDN's have been 
	doing it for years. CloudFlare [free] is your ~~cheapest~~ best friend. Pairing it with Github pages [free] is a 
	poor developer's dream. 
	- Can you go Serverless/FAAS for your backend? You no longer need to maintain or monitor hardware, you get infinite* 
	scaling out of the box. The tradeoff is that your costs will vary with usage, which can be nice for startups. 


# Before your first staging environment deploy
- Unit test suite - Yeah yeah, TDD. But be honest, when's the last time you started a side-project with TDD? You'll thank 
yourself when you come back to your code after 2 weeks, or even just a couple of days. It's also a pre-req for some of the next points.
- Code Coverage/Code Quality tools - When I feel that I have an application that can actually run on a server is when I 
know I need to take a step back and look at all the things that I missed. Code coverage/quality tools are like a bucket of 
cold water, they help stifle that feeling of euphoria that stops you from really digging into your code. 
- Forward your logs to a centralized logging system (Cloud-watch is fine, if you don't plan on actually debugging your app.) 
Loggly [free] is great. Make sure you forward environment data and user data to your log aggregator as well, to give your 
logs context. 
- Put a CDN like CloudFlare [free] in front of your site if you haven't already. You definitely don't have the traffic yet 
that requires it, but don't wait until you're ready to launch. Its time-consuming, error prone and can cause DNS downtime, 
even if you don't misconfigure something. It's not something you want to leave to the last minute. 
- Write documentation/setup instructions as you start building your Stage environment. Your documentation should always 
be relative to Stage, **NOT** Production. You will forget. You will copy and paste from your docs, and you will run a 
destructive operation against your production database. [Cough..](https://np.reddit.com/r/cscareerquestions/comments/6ez8ag/accidentally_destroyed_production_database_on/)
	- List all the weird/one-off configuration you had to do to get your staging server working. New accounts on 3rd 
	party services, ip whitelisting, database population, you'll need this checklist when you spin up Production, and 
	finding out whats different between Prod and Stage is going to be a huge pain without it. Infrastructure as code/ 
	Configuration Management is your friend here, but may not be enough by itself. 
- Follow modern infrastructure practices. Infrastructure as code and configuration management are buzzwords for a reason. 
And they don't have to be super complicated. You don't need to design the Mona Lisa of Chef cookbooks. At a bare minimum 
make sure that you can spin up a whole environment with the click of a single button. Automation is the key here. You'll 
be doing this a lot more than you'd expect, so take some time and do it right. When you find yourself under the gun, needing 
to scale your environment, you'll be thankful. 
- Version your code. Create releases, tag your software, its incredibly useful when debugging what software your actually 
running in different environments. It also makes it much easier to deploy previous versions when you want to do regression 
testing, or rollback a broken deployment. Check out something like [CapsuleCD](https://github.com/AnalogJ/capsulecd) [free] 
which can build, test, tag, merge branches and release your software automatically. 

# Before your first prod deploy
- Automate your backups. This is probably obvious to everyone, but a backup process without a verified restore process is 
useless. Try to setup a weekly backup and restore of your staging environment database. Use the same code/process you would in Production. 
- Write a script to populate your database with test data. Massive amounts of test data. [Faker.js](https://github.com/marak/Faker.js/) 
has an API. Check how your Staging environment actually handles real data, not just the toy amounts you've thrown in. 


# Once your application is live
- Track the versions of your application's dependencies, and their dependencies, 
[it's turtles all the way down](https://en.wikipedia.org/wiki/Turtles_all_the_way_down). This is to ensure that you know 
what software makes up your stack, but also so you can be notified of bug fixes and security issues.
- Make sure you have monitoring in place. 
	- Pingdom [free] will let notify you if your application is inaccessible externally. 
	- Track system metrics like CPU and memory load on your servers. NewRelic [free], Librato [free] and StackDriver [free] work well. 
	- Configure a user analytics & monitoring solution like Google Analytics [free]. Setup alerts when your traffic 
	increases or drops more than 15%.  


This is just my checklist, but I'd love to hear yours. Is there any devopsy related tasks you think I'm missing? 
