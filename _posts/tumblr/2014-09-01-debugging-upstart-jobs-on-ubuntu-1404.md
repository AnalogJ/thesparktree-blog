---
layout: post
title: Debugging Upstart Jobs on Ubuntu 14.04
date: '2014-09-01T15:22:00-07:00'
cover: '/assets/images/cover_ubuntu.png'
subclass: 'post tag-post'
tags:
- upstart
- linux
- ubuntu
- debugging
redirect_from: /post/96381672984/debugging-upstart-jobs-on-ubuntu-1404
disqus_id: 'http://blog.thesparktree.com/post/96381672984'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'
---

Before you begin, you should be (intimately) familiar with the [Upstart Cookbook](http://upstart.ubuntu.com/cookbook/). It's an incredible resource for understanding the in's and out's of Upstart and its configuration.

That said, unfortunately its still pretty difficult to debug Upstart jobs. You'll get messages like "Job failed to start" or "Unknown job"  without any obvious reasons why. The following is just a collection of the different methods I've found useful to debug Upstart jobs that are acting up.

# Verify job configuration location

Upstart jobs are located in `/etc/init/` and are text files named `foo.conf` where `foo` is your job name.
Session jobs can be found in one of the following directories:

- `$XDG_CONFIG_HOME/upstart/` (or `$HOME/.config/upstart/` if `$XDG_CONFIG_HOME` not set).
- `$HOME/.init/` (deprecated - supported for legacy User Jobs).
- `$XDG_CONFIG_DIRS`
- `/usr/share/upstart/sessions/`

# Check the job using the built-in validators

The built in validators are pretty basic, but they can help you catch simple errors, and save you from running into migration errors.

```bash
$ init-checkconfig foo.conf
$ initctl check-config
```

# Check the Job logs

The first and most obvious way to debug anything is to check the log files.
By default all Upstart jobs will log their output to a log file located at `/var/log/upstart/foo.log` where `foo` is your job name.
_Note:_ Session/User jobs have a special log location: `~/.cache/upstart/foo.log`

# Enable Verbose/Debug mode

If the log files aren't helpful enough, you can enable verbose debugging using

```bash
sudo initctl log-priority debug
sudo start foo
```

# Grep `dmesg` for related information
If the logs still don't show any new information about why the job is failing, you can try `grepping` the output of `dmesg`.

    sudo dmesg | grep foo

This has helped me solve `start: Job failed to start` issues where the errors occured in the `pre-start script` stanza.

# Force reload Upstart configuration

While this should be unnecesssary (Upstart watches for changes to the config directories), you can force a reload

	sudo initctl reload-configuration

# Solving `Unknown Job` errors

In my experience `start: Unknown job: foo` errors happen for three reasons.

1. You are incorrectly spelling/calling the job  - `/etc/init/foo-job.conf` should be called by `start foo-job`

    Solving the first case is simple, stop being stupid. You can verify that your job exists by `initctl list | grep foo`

2. Theres an error in the job configuration file

    Debugging the second case is a bit more difficult. Job configuration is loaded immediately on system startup, and you will have to check syslog for errors related to your specific job. I've had luck grepping `dmesg` as well.

3. You are attempting to start a Session job and a Upstart session has not been started.

    If you are trying to start a session job, ensure that there is a valid Upstart session running `echo "$UPSTART_SESSION"`. Make sure that you are running your terminal as the correct user. By default Ubuntu will start a Upstart session for you.