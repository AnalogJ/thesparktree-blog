---
layout: post
title: CapsuleCD v2 Released
date: '2017-08-06T01:19:33-08:00'
cover: '/assets/images/cover_github.png'
subclass: 'post tag-post'
tags:
- ruby
- nodejs
- python
- golang
- chef
- capsulecd
- docker
navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

[CapsuleCD](https://github.com/AnalogJ/capsulecd) is made up of a series of scripts/commands that make it easy for you to package and release a new version of your library artifact (Ruby gem, Npm package, Chef cookbook.. ) while still following best practices: 

- bumping `semvar` tags
- regenerating any `*.lock` files
- validates all dependencies exist and are free of vulnerabilities
- runs unit tests & linters
- uploads versioned artifact to community hosting service (rubygems/supermarket/pypi/etc)
- creating a new git tag
- pushing changes back to source control & creating a release
- and others..

While `CapsuleCD` **was** a series of scripts, with the release of **v2** that's no longer the case. 

`CapsuleCD` has been re-written, and is now available as a [static binary](https://github.com/AnalogJ/capsulecd/releases) on [`macOS`](https://github.com/AnalogJ/capsulecd/releases/download/v2.0.10/capsulecd-darwin-amd64) and [`Linux`](https://github.com/AnalogJ/capsulecd/releases/download/v2.0.10/capsulecd-linux-amd64) (`Windows` and `NuGet` support is hopefully coming soon)

You no longer need to worry that the version of Ruby used by your library & `gemspec` is different than the version required by `CapsuleCD`. If you maintain any Python or NodeJS libraries, this also means that a Ruby runtime for just for CapsuleCD is unnecessary. The `CapsuleCD` [Docker](https://hub.docker.com/r/analogj/capsulecd/tags/) images for other languages are much slimmer, and based off standard community images. 

Releasing a new version of your Ruby library hasn't changed, it's as easy as downloading the [binary](https://github.com/AnalogJ/capsulecd/releases) and running:

```
CAPSULE_SCM_GITHUB_ACCESS_TOKEN=123456789ABCDEF \
CAPSULE_SCM_REPO_FULL_NAME=AnalogJ/gem_analogj_test \
CAPSULE_SCM_PULL_REQUEST=4 \
CAPSULE_RUBYGEMS_API_KEY=ASDF12345F \
capsulecd start --scm github --package_type ruby
```

Click below to watch a screencast of `CapuleCD` in action:

<p align="center">
<a href="https://analogj.github.io/capsulecd">
  <img alt="CapsuleCD screencast" width="800" src="https://cdn.rawgit.com/AnalogJ/capsulecd/v2.0.10/capsulecd-screencast.png">
  </a>
</p>


<div class="github-widget" data-repo="AnalogJ/capsulecd"></div>






