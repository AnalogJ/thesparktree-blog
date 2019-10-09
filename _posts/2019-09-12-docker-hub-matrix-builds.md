---
layout: post
title: 'Docker Hub - Matrix Builds and Tagging using Build Args'
date: '19-09-12T01:19:33-08:00'
cover: '/assets/images/cover_docker_hub.png'
subclass: 'post tag-post'
tags:
- docker
- docker_hub
- devops
- linux
- automation

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

If you're a heavy user of Docker, you're already intimately familiar with Docker Hub, the official Docker Image registry.
One of the best things about Docker Hub is it's support for Automated Builds, which is where Docker Hub will watch a
Git repository for changes, and automatically build your Docker images whenever you make a new commit.

This works great for most simple use cases (and even some complex ones), but occasionally you'll wish you had a bit more control
over the Docker Hub image build process.

That's where Docker's [Advanced options for Autobuild and Autotest](https://docs.docker.com/docker-hub/builds/advanced/)
guide comes in. While it's not quite a turn key solution, Docker Hub allows you to override the `test`, `build` and `push`
stages completely, as well as run arbitrary code `pre` and `post` each of those stages.


As always, here's a Github repo with working code if you want to skip ahead:

<div class="github-widget" data-repo="AnalogJ/docker-hub-matrix-builds"></div>


## Goal

So what's the point? If Docker Hub works fine for most people, what's an actual use case for these Advanced Options?

Lets say you have developed a tool, and you would like to distribute it as a Docker image. The first problem is that you'd
like to provide Docker images based on a handful of different OS's. `ubuntu`, `centos6`, `centos7` and `alpine`
Simple enough, just write a handful of Dockerfiles, and use the `FROM` instruction.
But lets say that you also need to provide multiple versions of your tool, and each of those must also be distributed as a
Docker Image based on different OS's.

Now the number of Dockerfiles you need to maintain has increased significantly. If you're familiar with Jenkins, this would
be perfect for a "Matrix Project".

Here's what our Docker naming scheme might look like:

|      | ubuntu    | centos6    | centos7    | alpine    |
|------|-----------|------------|------------|-----------|
| v1.x | v1-ubuntu | v1-centos6 | v1-centos7 | v1-alpine |
| v2.x | v2-ubuntu | v2-centos6 | v2-centos7 | v2-alpine |
| v3.x | v3-ubuntu | v3-centos6 | v3-centos7 | v3-alpine |

As our software grows, you could image other axises being added: architectures, software runtimes, etc.

## Build Arguments

Alright, so the first part of the solution is just making use of Dockerfile templating, also known as [build arguments](https://docs.docker.com/engine/reference/commandline/build/#set-build-time-variables---build-arg)

To keep the number of Dockerfiles to the minimum, we need to pick an axes that minimizes the number of changes required.
In this example we'll choose to create a separate Dockerfile for each OS, reusing it for each branch of our software.

```Dockerfile
FROM ubuntu
ARG software_version

RUN apt-get update && apt-get install -y <dependencies> \
    ... \
    curl -o /usr/bin/myapp https://www.company.com/${software_version}/myapp-${software_version}

```

Now we can reuse this single Dockerfile to build 3 Docker images, running 3 different versions of our software:

```
docker build -f ubuntu/Dockerfile --build-arg software_version=v1.0 -t v1-ubuntu .
docker build -f ubuntu/Dockerfile --build-arg software_version=v2.1 -t v2-ubuntu .
docker build -f ubuntu/Dockerfile --build-arg software_version=v3.7 -t v3-ubuntu .
```

## Project Structure
Looks great so far, but Docker Hub doesn't support configuring Build Arguments though their web ui. So we'll need to use the
"Advanced options for Autobuild" documentation to override it.

At this point our project repository probably looks something like this:

```
project/
├── ubuntu/
│   └── Dockerfile
├── centos6/
│   └── Dockerfile
├── centos7/
│   └── Dockerfile
...
```

Docker Hub requires that the hook override directory is located as a sibling to the Dockerfile.
To keep our repository DRY, we'll instead create a `hook` directory at the top level, and symlink our `build` and `push`
scripts into a hooks directory beside each Dockerfile. We'll also create an empty `software-versions.txt` file in the project root,
which we'll use to store the versions of our software that needs to be automatically build. We'll discuss this further in the next section.

```
project/
├── software-versions.txt
├── hooks/
│   ├── build
│   └── push
├── ubuntu/
│   ├── hooks/
│   │   ├── build (symlink)
│   │   └── push (symlink)
│   └── Dockerfile
├── centos6/
│   ├── hooks/
│   │   ├── build (symlink)
│   │   └── push (symlink)
│   └── Dockerfile
├── centos7/
│   ├── hooks/
│   │   ├── build (symlink)
│   │   └── push (symlink)
│   └── Dockerfile
...
```

Now that we have our project organized in a way that Docker Hub expects, lets populate our override scripts

## Docker Hub Hook Override Scripts


Docker Hub provides the following environmental variables which are available to us in the logic of our scripts.

- `SOURCE_BRANCH`: the name of the branch or the tag that is currently being tested.
- `SOURCE_COMMIT`: the SHA1 hash of the commit being tested.
- `COMMIT_MSG`: the message from the commit being tested and built.
- `DOCKER_REPO`: the name of the Docker repository being built.
- `DOCKERFILE_PATH`: the dockerfile currently being built.
- `DOCKER_TAG`: the Docker repository tag being built.
- `IMAGE_NAME`: the name and tag of the Docker repository being built. (This variable is a combination of `DOCKER_REPO`:`DOCKER_TAG`.)

The following is a simplified version of a `build` hook script that we can use to override the `build` step on Docker Hub.
Keep in mind that this script is missing some error handling for readability reasons.

```bash
#!/bin/bash

###############################################################################
# WARNING
# This is a symlinked file. The original lives at hooks/build in this repository
###############################################################################

# original docker build command
echo "overwriting docker build -f $DOCKERFILE_PATH -t $IMAGE_NAME ."

cat "../software-versions.txt" | while read software_version_line
do
        # The new image tag will include the version of our software, prefixed to the os image we're currently building
        IMAGE_TAG="${DOCKER_REPO}:${software_version_line}-${DOCKER_TAG}"

        echo "docker build -f Dockerfile --build-arg software_version=${software_version_line} -t ${IMAGE_TAG} ../"
        docker build -f Dockerfile --build-arg software_version=${software_version_line} -t ${IMAGE_TAG} ../
done

```

The `push` script is similar:

```bash
#!/bin/bash

###############################################################################
# WARNING
# This is a symlinked file. The original lives at hooks/push in this repository
###############################################################################

# original docker push command
echo "overwriting docker push $IMAGE_NAME"

cat "../software-versions.txt" | while read software_version_line
do
    # The new image tag will include the version of our software, prefixed to the os image we're currently building
    IMAGE_TAG="${DOCKER_REPO}:${software_version_line}-${DOCKER_TAG}"

    echo "docker push ${IMAGE_TAG}"
    docker push ${IMAGE_TAG}
done

```

You should have noticed the `software-versions.txt` above. It's basically a text file that just contains version numbers for
our `myapp` software/binary.

```
master
v1.0
v2.1
v3.7
```
This file is then read line-by-line, and each line is passed into a docker build command via `--build-arg`. It's also used as the
version component in the Docker image build tag.

## Docker Hub Configuration

The final component necessary to successfully build these images is to configure the Docker Hub project correctly.

<img src="{{ site.url }}/assets/images/docker-hub/docker-hub-configuration.png" alt="docker hub configuration" style="max-height: 500px;"/>

## Fin

Again, here's the Github repo with working code (using `jq` as our example software tool to be installed):

<div class="github-widget" data-repo="AnalogJ/docker-hub-matrix-builds"></div>
