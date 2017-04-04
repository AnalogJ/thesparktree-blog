---
layout: post
title: Continuous Delivery for Versioned Artifacts/Libraries (Npm, Chef, Gems, Bower,
  Pip, etc)
date: '2016-04-12T12:13:11-07:00'
cover: 'assets/images/cover_github.png'
subclass: 'post tag-fiction'
tags:
- automation
- devops
- ci
- sysadmin
- python
- ruby
- nodejs
redirect_from: /post/142690115934/continuous-delivery-for-versioned
disqus_id: 'http://blog.thesparktree.com/post/142690115934'
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'
---
So you're the devops/automation guy or gal on your team. You live and die by “[Automate all the things](https://memegenerator.net/instance/9449708)”. Or maybe you just like the fact that your automated CI tests have saved you from spending hours debugging in production. That's awesome, that's how I got here too.

If I was to ask you about your production deployments, you wouldn't hesitate to tell me about all the automation you've put in place. But if I ask you about your build artifacts/libraries pipeline I'd probably get a cautious look and we would have a conversation like this:

- __Me:__ How do you release new versions of your Chef cookbooks?
- __You:__ We just bump up the version in the `metadata.rb` file and commit it.
- __Me:__ But you test it right?
- __You:__ Oh we have a full CI pipeline for it, every commit is tested.
- __Me:__ What about handling the version number embedded in your `Berksfile.lock`?
- __You:__ Right. We update that by running `berks install` after we bump up the version. Then we commit, and push it to Github.
- __Me:__ Do you do dependency checking? Lint your cookbook syntax? Run code coverage tools in addition to standard CI?
- __You:__ Oh we have a pretty simple/general purpose CI script, never got around to setting those up.
- __Me:__ What about actual releases? How do you get your new cookbook version into the community repo (Supermarket) or your Chef Server?
- __You:__ We use `knife upload` or `berks upload`. Or maybe its `knife cookbook upload`. Something like that.
- __Me:__ And then you create a git tag and push that to Github too right?
- __You:__ uhhh.. Of course.
- __Me:__ Do you update a `CHANGELOG.md` with a list of the changes between versions?
- __You:__ Sometimes, if its a big enough change.

This is obviously a very pointed example thats specific to Chef cookbooks, but versioning and releasing your library (written in any language) is just as important as releasing your actual application software. It can be hard to remember all the steps required, especially for more mature libraries which you don’t update very often. This makes it perfect for automating.

## CapsuleCD Infomercial

[CapsuleCD](https://github.com/AnalogJ/capsulecd) is a generic Continuous Delivery pipeline for versioned artifacts and libraries. Don't worry, I'm not trying to convince you to throw away all your CI scripts and replace your Jenkins server. [CapsuleCD](https://github.com/AnalogJ/capsulecd) is meant to work with your existing CI, not complete with it. It's goal is to bring automation to the packaging and deployment stage of your library release cycle.
Depending how you set it up (and how much you trust your Unit Tests), every Pull Request could automatically start CapsuleCD to generate a new release of your library (Continuous Deployment) or just notify Ops to kick off CapsuleCD (Continuous Delivery).

<div class="github-widget" data-repo="AnalogJ/capsulecd"></div>

## How's it work?

[CapsuleCD](https://github.com/AnalogJ/capsulecd) is configurable CLI application which can be heavily customized. It can support package/release management for libraries written in any language, but comes with built-in support for the following languages:

- Javascript (Bower)
- Node (Npm)
- Ruby (Gem)
- Chef (Cookbooks)
- Python (Pip)

Like Docker, [CapsuleCD](https://github.com/AnalogJ/capsulecd) follows the ideology of "batteries included but removable". Every supported language has a base release pipeline that’s designed to follow the best practices of that language. This includes things like:

- automatically bumping the semvar version number
- regenerating any `*.lock` files/ shrinkwrap files with new version
- creating any recommended files (eg. `.gitignore`)
- validates all dependencies exist (by vendoring locally)
- running unit tests
- source minification
- linting library syntax
- generating code coverage reports
- updating changelog
- uploading versioned artifact to community hosting service (rubygems/supermarket/pypi/etc)
- creating a new git tag and pushing changes back to source control (github)
- creating a new release in source control (github) and attaching any common artifacts

As you can see, some steps are only applicable for some languages and not others. Other steps only make sense for public libraries, like uploading them to the community repos. As mentioned earlier, every step listed is configurable, extendable and can be completely overridden if needed.

## Cavaets

While [CapsuleCD](https://github.com/AnalogJ/capsulecd) is very flexible, it's a bit opinionated. It’s built around Git but only supports Github right now (adding GitLab and Bitbucket support has been left as a community exercise, or if enough people request it). It also works best when paired with a CI server.

I’d also recommend that you run [CapsuleCD](https://github.com/AnalogJ/capsulecd) inside a Docker container, so you don’t have to worry about accidentally clobbering your system pip/ruby/cookbook cache between runs. But this won’t be a problem once [vendoring support](https://github.com/AnalogJ/capsulecd/issues/25) is added, something that’s at the top of the to-do list.

[CapsuleCD](https://github.com/AnalogJ/capsulecd) was designed around the premise that pull requests precede releasing a new version, but you can also create a release manually from the HEAD of the default branch.

## How do I wire it up?

Using [CapsuleCD](https://github.com/AnalogJ/capsulecd) is as easy as:

```bash
gem install capsulecd
CAPSULE_SOURCE_GITHUB_ACCESS_TOKEN=1234567890ABCDEF \
CAPSULE_RUNNER_REPO_FULL_NAME=AnalogJ/lexicon \
CAPSULE_RUNNER_PULL_REQUEST=10 \
capsulecd start --source github --package_type python
```
or with Docker

```bash
docker pull AnalogJ/capsulecd:python
docker run -e "CAPSULE_SOURCE_GITHUB_ACCESS_TOKEN=1234567890ABCDEF" \
-e "CAPSULE_RUNNER_REPO_FULL_NAME=AnalogJ/lexicon" \
-e "CAPSULE_RUNNER_PULL_REQUEST=10" \
AnalogJ/capsulecd:python \
capsulecd start --source github --package_type python
```

Basically what you’re doing is specifying the `GITHUB_ACCESS_TOKEN` for the automation user who will be pulling the source from Github, bumping the version, making any code changes, tagging the new version and pushing back to Github.
The `REPO_FULL_NAME` environmental variable is used to specify the repo we’re processing.
The `PULL_REQUEST` number tells [CapsuleCD](https://github.com/AnalogJ/capsulecd) which branch to process and create a new release from.

## Ugh, Ruby? My library is written in Go/Lisp/Javascript/Python/etc.

To be honest, [CapsuleCD](https://github.com/AnalogJ/capsulecd) isn’t meant for library developers, its meant for the Ops/Devops team members that maintain the releases. Ruby is a powerful language, and the most popular configuration management tools (Puppet/Chef) are written in Ruby, which means it’s one less language that your Ops guys need to learn (because who really wants to do package management in Lisp).

## All our Rubygems are private, how do I override the publish step to point to our private Gem server?

Check out the [Step pre/post hooks and override](https://github.com/AnalogJ/capsulecd/blob/master/README.md#step-prepost-hooks-and-overrides) section of the README.md


<div class="github-widget" data-repo="AnalogJ/capsulecd"></div>
