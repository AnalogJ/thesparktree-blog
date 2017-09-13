---
layout: post
title: Devops for Startups & Small Teams
date: '2017-09-13T01:19:33-08:00'
cover: '/assets/images/cover_devops3.png'
subclass: 'post tag-post'
tags:
- devops
- startup
- teams
- startup
- automation
- github
- bitbucket
- loggly
- docker
- travisci
- circleci
- waffle
- cloudflare
- pingdom
- googleanalytics
- newrelic
- capsulecd
- codecov
- coverallsio
- stackdriver

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

When you're working on a side-project or at a startup as part of a small focused team, it can be hard to get away from
the heads-down mentality of "just do it". But sometimes it can be valuable to step back and recognize that a bit of upfront
infrastructure work can save you days or even weeks of time getting your MVP up and running.

The following are the quick and dirty Devops patterns & procedures that I put in place before working on any new system.
I primarily focus on free tools and services because of how cheap I am, so feel free to replace them comparable tools of your choice,
you big spender, you.

# Before your first line
- **Store your code in Git** - [Github](https://github.com/) *[free open source]*/[Bitbucket](https://bitbucket.org/) *[free private]* -
there shouldn't be more to say here other than, store your source in a VCS from day 1.
- Design your app with **multiple environments** in mind. You should be able to switch between Local/Stage/Production development
with no code changes, just configuration changes (via environmental variables or a config file). I love [nconf](https://github.com/indexzero/nconf)
for NodeJS, but most languages have something similar.
- **Isolate your configuration.** Its probably not necessary to move your configuration into a compeltely separate system yet,
but make sure you can easily if you scale. Sprinkling your configuration in multiple places is just asking for an application re-write.
- **Follow a branching pattern.** At it's simplest it could just be 2 branches, "master" and "develop" or you could go nuts
and follow [gitflow](http://nvie.com/posts/a-successful-git-branching-model/). It doesn't matter, as long as you follow
the damn thing, and don't just commit directly to master. Setup branch protection to disable commits to "master".
This is going to be important later when you start doing Continuous Integration (CI). Bad habits are hard to break.
- **Setup CI**. You don't need to go full throttle with a standalone Jenkins server. Just make sure your code is compiling
in a clean-room environment, that doesn't include the dozens of apps and libraries you already have installed on your
dev machine. [TravisCI](https://travis-ci.org/) *[free]* and [CircleCI](https://circleci.com) *[free]* are great, and integrate
with Github/Bitbucket. At a bare minimum build your artifacts inside a clean Docker container.
- Setup an **issue tracker/project management board**. [Waffle.io](https://waffle.io) *[free]* is great and integrates with Github,
but you may be able to just get away with [Github Project Boards](https://help.github.com/articles/creating-a-project-board/) *[free]* to start
- Make some Architecture decisions:
	- Decide if you can get away with a [static frontend](https://github.com/myles/awesome-static-generators) or SPA
	architecture for your front end. If you can, you'll get infinite scaling of your front-end for almost free.
	Distributing static files is a solved problem--CDN's have been doing it for years. [CloudFlare](https://www.cloudflare.com) *[free]*
	is your ~~cheapest~~ best friend. Pairing it with Github pages [free] is a poor developer's dream.
	- Can you go Serverless/FAAS for your backend? You no longer need to maintain or monitor hardware, you get infinite*
	scaling out of the box. The tradeoff is that your costs will vary with usage, which can be a good thing for startups.

# Before your first staging environment deploy
- Have a **unit test suite** - Yeah yeah, TDD. But be honest, when's the last time you started a project with TDD? Still, you'll thank
yourself when you come back to your code after 2 weeks, or even just a couple of days. It's also a pre-req for some of the next points.
- **Code Coverage/Code Quality** tools - When I feel that I have an application that can actually run on a server is when I
know I need to take a step back and look at all the things that I missed. Code coverage/quality tools are like a bucket of
cold water, they help stifle that feeling of euphoria that stops you from really digging into your code. A nice UI really helps
and I'm a big fan of [Coveralls.io](https://coveralls.io/) *[free open source]* and [CodeCov](https://codecov.io/) *[free open source]*,
both have great integration with SCM's and CI platforms.
- **Forward your logs** to a centralized logging system (Cloud-watch is fine, if you don't plan on actually debugging your app.)
[Loggly](https://www.loggly.com) *[free]* is great. Make sure you forward environment data and user data to your log aggregator as well, to give your
logs context.
- **Use a CDN** like [CloudFlare](https://www.cloudflare.com) *[free]* in front of your site if you haven't already. You definitely don't have the traffic yet
that requires it, but don't wait until you're ready to launch. Its time-consuming, error prone and can cause DNS downtime,
even if you don't misconfigure something. It's not something you want to leave to the last minute.
- **Write documentation/setup instructions** as you start building your Stage environment. Your documentation should always
be relative to Stage, **NOT** Production. You will forget. You will copy and paste from your docs, and you will run a
destructive operation against your production database. [Cough..](https://np.reddit.com/r/cscareerquestions/comments/6ez8ag/accidentally_destroyed_production_database_on/)
	- List all the weird/one-off configuration you had to do to get your staging server working. New accounts on 3rd
	party services, ip whitelisting, database population, you'll need this checklist when you spin up Production, and
	finding out whats different between Prod and Stage is going to be a huge pain without it. Infrastructure-as-code/Configuration Management
	 is your friend here, but may not be enough by itself.
- **Follow modern infrastructure practices.** [Infrastructure-as-code](https://www.terraform.io/) and [Configuration](https://www.chef.io/chef/) [Management](https://puppet.com/) are buzzwords for a reason.
And they don't have to be super complicated. You don't need to design the Mona Lisa of Chef cookbooks. At a bare minimum
make sure that you can spin up a whole environment with the click of a single button. Automation is the key here. You'll
be doing this a lot more than you'd expect, so take some time and do it right. When you find yourself under the gun, needing
to scale your environment, you'll be thankful.
- **Version your code.** Create releases, tag your software, its incredibly useful when debugging what software your actually
running in different environments. It also makes it much easier to deploy previous versions when you want to do regression
testing, or rollback a broken deployment. Check out something like [CapsuleCD](https://github.com/AnalogJ/capsulecd)
which can build, test, tag, merge branches and release your software automatically.
- **Setup Continuous Deployments** - If you're already using a CI platform to test your code, why not automatically deploy your
validated code to your Staging environment? Depending on your application architecture, this may be a bit complicated, but
having your CI tested code deployed to a staging environment automatically is going to drastically improve your development
cadence while still ensuring stability. And if your stability is being effected, prioritize your tests, they're supposed to
catch 90% of your errors before they even get to a staging env.

# Before your first prod deploy
- **Automate your backups.** This is probably obvious to everyone, but a backup process without a verified restore process is
useless. Try to setup a weekly backup and restore of your staging environment database. Use the same code/process you would in Production.
- Write a script to **populate your database** with test data. Massive amounts of test data. [Faker.js](https://github.com/marak/Faker.js/)
has an API. Check how your Staging environment actually handles real data, not just the toy amounts you've thrown in.


# Once your application is live
- Track the versions of your **application's dependencies, and their dependencies**,
[it's turtles all the way down](https://en.wikipedia.org/wiki/Turtles_all_the_way_down). This is to ensure that you know
what software makes up your stack, but also so you can be notified of bug fixes and security issues.
- Make sure you have **monitoring** in place.
	- [Pingdom](https://www.pingdom.com/free) *[free]* will let notify you if your application is inaccessible externally.
	- Track system metrics like CPU and memory load on your servers. [NewRelic](https://newrelic.com/) *[free]*,
	[Librato](https://www.librato.com/) *[free]* and [StackDriver](https://cloud.google.com/stackdriver/) *[paid]* work well.
	- Configure a user analytics & monitoring solution like [Google Analytics](https://www.google.com/analytics/) *[free]*. Setup alerts when your traffic
	increases or drops more than 15%.


This is just my checklist, but I'd love to hear yours. Is there any devopsy related tasks you think I'm missing?
