---
layout: post
title: 'Running Cron in Docker'
date: '21-04-26T01:19:33-08:00'
cover: '/assets/images/cover_docker.jpg'
subclass: 'post tag-post'
tags:
- docker
- cron

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

Running `cron` in a Docker container is incredibly difficult to do correctly.
This is partially because `cron` was designed to run in an environment that looks very different than a docker container,
and partially because what we traditionally think of as `cron` is actually a different tool in each flavor of Linux.

As always, here's a Github repo with working code if you want to skip ahead:

<div class="github-widget" data-repo="AnalogJ/docker-cron"></div>


## What is `cron`

> The software utility **cron** also known as **cron job** is a time-based job scheduler in Unix-like computer operating
systems. Users who set up and maintain software environments use cron to schedule jobs (commands or shell scripts) to run
periodically at fixed times, dates, or intervals. It typically automates system maintenance or administration—though its
general-purpose nature makes it useful for things like downloading files from the Internet and downloading email at regular
intervals.

[https://en.wikipedia.org/wiki/Cron](https://en.wikipedia.org/wiki/Cron)

Basically it's a language/platform/distro agnostic tool for scheduling tasks/scripts to run automatically at some interval.

## Differences between various versions

Though `cron`'s API is standardized, there are multiple implementations, which vary as the default for various distros
([dcron](http://www.jimpryor.net/linux/dcron.html), [cronie](https://github.com/cronie-crond/cronie),
[fcron](http://fcron.free.fr/) and [vixie-cron](https://directory.fsf.org/wiki/Vixie-cron))

To add to the complexity, some of `cron`'s functionality is actually defined/provided by `anachron`. `anacron` was
previously a stand-alone binary which was used to run commands periodically with a frequency defined in days. It works
a little different from cron; assumes that a machine will not be powered on all the time.

So to summarize, there are multiple `cron` implementations, with differing flags & features, some with `anacron`
functionality built-in, and some without. In the following sections I'll call out different solutions for different
distros/`cron` implementations (keep an eye out for `NOTE:` blocks)

> NOTE: Installation instructions differ per distro
>
> - Debian/Ubuntu: `apt-get update && apt-get install -y cron && cron`
> - Alpine: `which crond` # comes pre-installed
> - Centos: `yum install -y cronie && crond -V`



## Config File

Let's start with a simple issue. `cron` is designed to run in a multi-user environment, which is great when you're running
`cron` on a desktop, but less useful when running `cron` in a docker container.

Rather than creating a user specific `crontab` file, in our Docker container we'll modify the system-level `crontab`.

Let's create/update a file called `/etc/crontab`

```
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed

* * * * * root date
```

This file will configure `cron` to run the `date` command every second. We'll talk about the output for this command in a later section.

> NOTE:
>
> - Debian/Ubuntu: replace the existing `/etc/crontab` which contains `anacron` entries
> - Alpine: the crontab file should be written to `/var/spool/cron/crontabs/root`, also the format is slightly different (the `user` field should be removed).
> - Centos: replace the existing `/etc/crontab` which contains `anacron` entries

## Foreground

Now that we have created a `cron` config file, we need to start `cron`. On a normal system, we would start `cron` as a
daemon, a background process usually managed by service manager. In the Docker world, the convention is 1 process per container,
 running in the foreground.

Thankfully most `cron` implementations support this, even though the flags may be different.

> NOTE: Running cron in the foreground differs per distro
>
> - Debian/Ubuntu: `cron -f -l 2`
> - Alpine: `crond -f -l 2`
> - Centos: `crond -n`


## Environment

As mentioned earlier, `cron` is designed to work in a multi-user environment, which also means the `cron` daemon cannot
make assumptions about the runtime environment (process environmental variables, etc). The way `cron` enforces this is
by starting each job with a custom environment, using an implementation specific environmental variables file (usually `/etc/environment`)

Since using environmental variables is a common configuration mechanism for Docker containers, we need a way to ensure the current
Docker container environment is passed into the cron sub-processes. The best way to do this is by creating a custom
entrypoint script which dumps the environment to the `cron` environment file, before starting `cron` in the foreground.

Create the following `/entrypoint.sh` script in your Docker image.

```bash
#!/bin/sh

env >> /etc/environment

# start cron in the foreground (replacing the current process)
exec "cron -f"
```

> NOTE:
>
> - Centos: unfortunately `cronie` doesn't read variables from `/etc/environment`.
>   - You'll need to manually source it before your script: `* * * * * root . /etc/environment; date`
>   - If you have multiple entries in your `crontab`, you can change the default `SHELL` for your `crontab` file, and make use of `BASH_ENV`
>
>        ```
>        SHELL=/bin/bash
>        BASH_ENV=/etc/environment
>        * * * * * root echo "${CUSTOM_ENV_VAR}"
>        ```

## STDOUT/STDERR

If you've been following along so far, you might be wondering why you're not seeing any output from `date` in your
terminal. That's because even though `cron` is running in the foreground, the output from its child processes is designed
to go to a log file (traditionally at `/var/log/cron`). Again, this might be fine on a standard linux host, but it's
sub-optimal for a Docker container.

Let's use some shell redirect magic to redirect the `STDOUT` and `STDERR` from our `cron` jobs, to the `cron` process
(running as the primary process in the Docker container, with [PID 1](https://en.wikipedia.org/wiki/Process_identifier)).

```
# >/proc/1/fd/1 redirects STDOUT from the `date` command to PID1's STDOUT
# 2>/proc/1/fd/2 redirects STDERR from the `date` command to PID1's STDERR

* * * * * root date >/proc/1/fd/1 2>/proc/1/fd/2
```

While `>/proc/1/fd/1 2>/proc/1/fd/2` may look intimidating, it's the most consistent way to pass `cronjob` logs to the container's
STDOUT, without leveraging clunky solutions like `crond && tail -f /var/log/cron`

> NOTE: this is unnecessary in Alpine, as long as you start cron with the following command:
> - Alpine: `crond -f -l 2`

## Cron package installation

Now that we have a working container with `cron`, we should take the time to clean up some of the unused cruft that our
`cron` package installs, specifically configs for `anacron`.

> NOTE:
>
> - Debian/Ubuntu: `rm -rf /etc/cron.*/*`
> - Alpine: `rm -rf /etc/periodic`
> - Centos: `rm -rf /etc/cron.*/*`

## Kill

Finally, as you've been playing around, you may have noticed that it's difficult to kill the container running `cron`.
You may have had to use `docker kill` or `docker-compose kill` to terminate the container, rather than using `ctrl + C` or `docker stop`.

Unfortunately, it seems like `SIGINT` is not always correctly handled by `cron` implementations when running in the foreground.

After researching a couple of alternatives, the only solution that seemed to work was using a process supervisor (like
`tini` or `s6-overlay`). Since `tini` was merged into Docker 1.13, technically, you can use it transparently by passing
`--init` to your docker run command. In practice you often can’t because your cluster manager doesn’t support it.

> NOTE: this is unnecessary in Centos, SIGTERM works correctly with `cronie` in the foreground.

## Putting it all together

Let's see what all of this would look like for an `ubuntu` base image.

Create a `Dockerfile`

```Dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y cron && which cron && \
    rm -rf /etc/cron.*/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["cron","-f", "-l", "2"]
```

Create an `entrypoint.sh`

```bash
#!/bin/sh

env >> /etc/environment

# execute CMD
echo "$@"
exec "$@"

```

Create a `crontab`

```

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed

* * * * * root date >/proc/1/fd/1 2>/proc/1/fd/2
* * * * * root echo "${CUSTOM_ENV_VAR}" >/proc/1/fd/1 2>/proc/1/fd/2

# An empty line is required at the end of this file for a valid cron file.

```

Build the Dockerfile and run it with `--init` (package `tini` or `s6-overlay` for containers in production)

```bash
docker build -t analogj/cron .
docker run --rm --name cron -e CUSTOM_ENV_VAR=foobar -v `pwd`/crontab:/etc/crontab analogj/cron
```

You should see output like the following:

```
foobar
Tue Apr 27 14:31:00 UTC 2021
```

# Fin

I've put together a working example of dockerized `cron` for multiple distros:

<div class="github-widget" data-repo="AnalogJ/docker-cron"></div>

## References
- https://hynek.me/articles/docker-signals/
- https://stackoverflow.com/questions/37458287/how-to-run-a-cron-job-inside-a-docker-container
