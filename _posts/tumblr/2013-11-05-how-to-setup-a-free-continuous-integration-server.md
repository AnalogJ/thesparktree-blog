---
layout: post
title: How to setup a Free Continuous Integration Server Using Cloudbees + Private
  Github
date: '2013-11-05T00:00:00-08:00'
cover: 'assets/images/cover_jenkins.jpg'
subclass: 'post tag-post'
tags:
- cloudbees
- github
- jenkins
redirect_from: /post/69449035595/how-to-setup-a-free-continuous-integration-server
disqus_id: 'http://blog.thesparktree.com/post/69449035595'
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'
---

### Better Integration Between Jenkins and GitHub (with the GitHub Jenkins Plugin)

The following steps will help setup your Cloudbees Jenkins Service for continuous integration via Github. Most of the documentation for this section came from here [http://blog.cloudbees.com/2012/01/better-integration-between-jenkins-and.html](http://blog.cloudbees.com/2012/01/better-integration-between-jenkins-and.html)


## Setup Cloudbees + Jenkins + Private Github

1. Go to your Jenkins instances root page.
2. If your Jenkins instance has security enabled, login as a user who has the `Overall | Administer` permission.
3. Select the `Manage Jenkins` link on the left-hand side of the screen.
4. Select the `Manage Plugins` link.
5. On the `Available` tab, select the `Github Plugin` and click the `Download and Install` button at the bottom of the page (if you do not got the Git Plugin installed, do not worry, Jenkins is smart enough to install/upgrade the Git plugin, where required).
6. Restart Jenkins once the plugins are downloaded (Note: users of Jenkins 1.442 or newer should be aware that the plugin currently requires a restart to function correctly).

## Configure Github Push Webhook

1. Goto your Jenkins instance job.
2. Select the `Configure` link on the left hand side of the screen.
3. In the `GitHub project` field, enter the URL of the GitHub project. If your GitHub project's git URL looks like: `git@github.com:username/project.git`,

	then the GitHub project should be: http://github.com/username/project/or if the project is private, you can get faster navigation with: https://github.com/username/project/


4. Go to your Jenkins instances root page.
5. Select the `Manage Jenkins` link on the left hand side of the screen.
6. Select the `Configure System` link.
7. In the `GitHub Web Hook` section select the `Let Jenkins auto-manage hook URLs` option.
8. Ensure you have provided at least one username and password for connecting to GitHub (the password is required as GitHub does not expose an API for managing the Post-Receive URLs).

Once you have configured your Jenkins instance for receiving the push notifications, you can enable jobs being triggered via the push notifications:

1. Goto your Jenkins instance job.
2. Select the `Configure` link on the left hand side of the screen.
3. Select the `Build when a change is pushed to GitHub checkbox` and save the configuration.

# Jenkins Build Scripts

Depending on your application environment you will need to run a command to start your test runners. Here are a few build scripts we use in our environments. Note: be careful when using `#!/bin/bash` at the beginning of the script, [it may produce unintended problems](http://stackoverflow.com/questions/11464883/jenkins-succeed-when-unit-test-fails-rails).

## Ruby RSpec
To use Ruby on DEV@Cloud, add the following to the beginning of your shell script build step:

```bash
curl -s -o use-ruby https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/use-ruby
RUBY_VERSION=1.9.3-p327 . ./use-ruby
```

The list of available versions is here: [https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/fc17/](https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/fc17/)

This will:

- Download and install the ruby -- if needed. We cache the installation on the slave, and try to give you the same slave. But even then, it's very fast.
- Setup your $PATH and other environment variables to use this ruby

You can then:

```bash
gem install --conservative bundler
bundle check || bundle install
rake spec:normal
```

# Ruby Gem

```bash
curl -s -o use-ruby https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/use-ruby
RUBY_VERSION=1.9.3-p327 . ./use-ruby
gem install --conservative bundler
bundle check || bundle install
rake spec:normal
gem build <gem name here>.gemspec
```

## Ruby-on-rails

```bash
curl -s -o use-ruby https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/use-ruby
RUBY_VERSION=1.9.3-p327 . ./use-ruby
gem install --conservative bundler
bundle check || bundle install
bundle exec rake
```

## Chef + Berkshelf + Foodcritic + Test-Kitchen

```bash
curl -s -o use-ruby https://repository-cloudbees.forge.cloudbees.com/distributions/ci-addons/ruby/use-ruby
RUBY_VERSION=1.9.3-p327 . ./use-ruby
gem install --conservative bundler
bundle check || bundle install
gem install foodcritic
foodcritic .
# kitchen test - this command will run the Vagrant file and test the application, can take a very long time. should only be uncommented when required.
```