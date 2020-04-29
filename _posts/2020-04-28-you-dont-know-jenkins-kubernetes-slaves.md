---
layout: post
title: You Don't Know Jenkins - Part 3
date: '2017-11-13T22:37:09-07:00'
cover: '/assets/images/cover_jenkins.jpg'
subclass: 'post tag-post'
tags:
- jenkins
- devops
- groovy
- chef
- dsl
- automation
categories: 'analogj'
logo: '/assets/logo-dark.png'
navigation: False
hidden: true
---


Jenkins is one of the most popular Continuous Integration servers ever. It supports an absurd amount of languages, frameworks, source code management systems and tools via plugins maintained by its active community.

One of the reason Jenkins has become[FILL OUT WITH MOER INTRO]

As your application and deployed infrastructure scales up, so too must your CI/CD system. Jenkins supports the concept of slave machines where you can offload your testing and automation, leaving the Jenkins master as the orchestrator for your jobs.

This works great in theory, however now theres an additional management overhead keeping the slave nodes up-to-date with the software required for your jobs. Under/over utilization also becomes a problem. Your peak job load may differ significantly from your baseline, meaning that lots of resources are wasted, or your slaves just can't keep up with the number of jobs in the queue, delaying your builds & tests.

Docker + Kubernetes fixes that.

[FILL OUT WITH MORE INFO]

## Table of Contents

- Assumptions

- Configure your Kubernetes Cluster

  - Jenkins Namespace

  - Convert Kubernetes Client Config to PFX

- Configure Kubernetes Jenkins Plugin

  - Add Jenkins Certificate Credential

  - Add Kubernetes Cloud

  - Configure Pod Templates

    - Official Jenkins Docker Agent Image

    - Custom Agent Images

- Configure Jobs

  - Freestyle Jobs

  - Pipeline Jobs

    - Pipeline Jobs using custom pod definitions

## Assumptions

I'm assuming that you already have a working (and accessible):

- Kubernetes cluster (v)

  - `master` nodes/API needs to be accessible via Jenkins

  - `kubectl` should be configured to communicate with your cluster

- Jenkins server (v2.199+)

  - You'll also want to install the [Kubernetes Plugin for Jenkins](https://plugins.jenkins.io/kubernetes/](https://plugins.jenkins.io/kubernetes/) (v1.24.0+)

This guide is not for Jenkins X, it assumes that you do not want to run [FILL IN INFORMATIION ABOUT JENKINX here]

## Configure your Kubernetes Cluster

Before we start configuring Jenkins, we'll need to ensure that our Kubernetes cluster has some basic configuration

### Jenkins Namespace

We should create a Jenkins specific namespace on our Kubernetes cluster, so we can isolate pods created from our Jenkins server

```
$ kubectl create namespace jenkins-kube-slaves
```

> Note: If you're planning on sharing this Kubernetes cluster with different Jenkins servers, you should probably use a unique namespace for each.

### Optional - Docker Registry Authentication

> This section is optional, and only required if you use a private registry, or have private images on Docker hub

If your team uses a private Docker registry to store your images, you'll need to tell Kubernetes how to authenticate against it. This is done using a Kubernetes secret.

Next, you'll need to create a Kubernetes secret that is used to authenticate against your docker registry

```bash
  kubectl create secret docker-registry docker-registry-auth-jenkins \
  --namespace="jenkins-kube-slaves" \
  --docker-server=https://index.private-registry-hostname.com \
  --docker-username=myusername \
  --docker-password=mypassworrd \
  --docker-email=myemail@corp.example.com
```

> Note: you can use [https://index.docker.io/v1/](https://index.docker.io/v1/) if your images are private but hosted on Docker Hub.

You'll want to deploy a pod to the `jenkins-kube-slaves` namespace manually to ensure that the credentials are valid.

### Convert Kubernetes Client Config to PFX

The Kubernetes Plugin for Jenkins requires a `*.pkf` formatted certificate authenticating against the Kubernetes API, rather than the standard `kubectl` config file format (`~/.kube/config`).

You can generate a `*.pkf` file by running the following commands

```bash
$ grep 'client-certificate-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> client.crt
$ grep 'client-key-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> client.key

# generate pkf file
$ openssl pkcs12 -export -clcerts -inkey client.key -in client.crt -out client.pfx -name "kubernetes-client" -passout pass:SECRET_PASSPHRASE
```

You can validate that your generated `*.pkf` file worked by querying the kubernetes cluster API with it

```bash
curl --cert client.pfx:SECRET_PASSPHRASE https://KUBERNETES_APISERVER_HOSTNAME:PORT/api/v1
```

> Note: the `SECRET_PASSPHRASE` value above should be replaced and treated as a password. The `*.pfx` passphrase is used to encrypt the `*.pfx` file contents before storing them on disk.

Now that we've configured our Kubernetes cluster, its time to setup Jenkins

## Configure Kubernetes Jenkins Plugin

The Kubernetes plugin is fairly complicated at first glance. There's a handful of settings that must be set for everything to work correctly. If you're following along, you'll want to pay close attention to the screenshots below.

### Add Jenkins Certificate Credential

The first thing we're going to need to do is add store our generated `client.pfx` file as a Jenkins Certificate Credential, so we can reference it in the Kubernetes plugin configuration.

<img src="{{ site.url }}/assets/images/jenkins-kubernetes-slaves/jenkins-certificate-credential.png" alt="docker hub configuration" style="max-height: 500px;"/>

> Note: You must specify the same `SECRET_PASSPHRASE` you used when generating your `*.pfx` file above.

### Add Kubernetes Cloud

Now we can finally start configuring our Jenkins server to communicate with our Kubernetes cluster.

> Note: If your security posture (and feature-set)  allows it, use a managed Kubernetes cluster like EKS or AKS. It'll make your life much easier.

<img src="{{ site.url }}/assets/images/jenkins-kubernetes-slaves/jenkins-kubernetes-configure.png" alt="docker hub configuration" style="max-height: 500px;"/>

> Note: in the screenshot above, I've disabled the "https certificate check" for testing. You'll want to make sure thats enabled in production. When you do so, you'll need to specify your Kubernetes server CA Certificate key in the box above.

### Configure Global Pod Templates

The Kubernetes plugin (when referenced in a Jenkins Pipeline job) is highly customizable. You can dynamically specify your pod configuration in the job, using syntax like the following:

```groovy
podTemplate(containers: [
    containerTemplate(name: 'maven', image: 'maven:3.3.9-jdk-8-alpine', ttyEnabled: true, command: 'cat')
]) {

    node(POD_LABEL) {
        stage('Get a Maven project') {
            git 'https://github.com/jenkinsci/kubernetes-plugin.git'
            container('maven') {
                stage('Build a Maven project') {
                    sh 'mvn -B clean install'
                }
            }
        }
    }
}
```

We'll discuss this in depth later. The issue using this syntax is that upgrading/changing the image means you have to edit each job that uses that image, which can be a hassle.

Personally, I find it more useful to setup a handful of "global" pod templates, that are usable everywhere, and reserve the Pipeline script synax for custom/one-off jobs.

So how do we configure global pod templates?

#### Official Jenkins Docker Agent Image

Jenkins communicates with its slaves using a Jenkins Agent. The logic for this Agent is packaged into a jar and automatically installed on your slave node when you register the slave with the Jenkins master.

This Agent software is also required for the dynamic Kubernetes slaves, however in this case it's baked into the docker image that you run.

The Jenkins developers have provided us with an image that has the Agent preconfigured so that it will work out of the box. It's based on Debian, but Alpine and Windows Nanoserver flavors exist as well.

It's available on docker hub: [jenkins/inbound-agent](https://hub.docker.com/r/jenkins/inbound-agent)

To use it, we'll configure a Pod Template, to look like the following:

<img src="{{ site.url }}/assets/images/jenkins-kubernetes-slaves/jenkins-pod-template-java.png" alt="docker hub configuration" style="max-height: 500px;"/>

The fields to pay attention to are the following

- **Namespace**  - this determines the namespace that Jenkins uses when it creates slaves on demand.

- **Label** - the most important field. The label(s) you specify here will be used in your Jenkins jobs to assign them to this dynamic slave. We'll call ours `kube-slave-java`.

- **Docker Image** - as mentioned above, `jenkins/inbound-agent` is a prebuilt image. In the next section we'll add custom Docker images (that include additional language runtimes like python/node/go/etc.)

- Optional - **ImagePullSecrets** - only required if you use a private Docker registry, or private Docker Hub images. Should have the exact name used in the **Docker Registry Authentication** section above.

    <img src="{{ site.url }}/assets/images/jenkins-kubernetes-slaves/jenkins-pod-template-secret.png" alt="docker hub configuration" style="max-height: 500px;"/>


#### Custom Agent Images

Now that you have a Pod Template configured using the official Jenkins Agent image, you might be thinking about all the custom software you've installed on your Jenkins server & slaves -- language runtimes, tools, fonts, etc.

Since  `jenkins/inbound-agent` is just a standard Docker image, you can customize it like you would any other Docker image.

Here's an example `Dockerfile` adding the Go language runtime to the `jenkins/inbound-agent` image, so you can use `go build` in your Jenkins jobs

```dockerfile
FROM jenkins/inbound-agent

# the jenkins/inbound-agent is configured to run as the `jenkins` user. To install new software & packages, we'll need to change back to `root`
USER root

# lets download & install the latest Go language runtime and tools.
# since this is a debian machine, we can also install standard packages using `apt-get`
RUN curl -O --silent --location https://dl.google.com/go/go1.13.10.linux-amd64.tar.gz && \
    mkdir -p /usr/local/go && \
    tar -xvf go1.13.10.linux-amd64.tar.gz -C /usr/local/go --strip 1 && \
    rm -f go1.13.10.linux-amd64.tar.gz

# lets setup some Go specific environmental variables
ENV GOROOT="/usr/local/go" \
 GOPATH="/home/jenkins/go"

# next, we'll customize the PATH env variable to add the `go` binary, and ensure that binaries on the GOROOT and GOPATH are also available.
ENV PATH="$PATH:/usr/local/go/bin:$GOROOT/bin:$GOPATH/bin"

# now that we've finished customizing our Jenkins image, we should drop back to the `jenkins` user.
USER jenkins

# finally, we'll setup the `go` cache directory (GOPATH), and test that the go binary is installed correctly.
RUN mkdir /home/jenkins/go && \
 go version 
```

Once you push this up to your Docker registry, you can reference it in a new Pod template, with a label like `kube-slave-go` or maybe `kube-slave-go1.13` if you care about the specific version of the language runtime.

While you could go off and build custom Docker images for all the languages you use, I've already created `jenkins/inbound-agent` based Docker images for most popular languages (go, ruby, node, python). Feel free to use them if you'd like.

<div class="github-widget" data-repo="AnalogJ/docker-jenkins-inbound-agent-runtimes"></div>

### Configure Jobs

Now that we have our Kubernetes plugin fully configured, its time to start running our Jenkins jobs on our cluster.

Though Jenkins has a multitude of different job types, they're all fundamentally based on one of the two core job types:

- Freestyle jobs

- Pipeline jobs

#### Freestyle Jobs

Lets look at freestyle jobs first. They've been around the longest, and most other job types can be configured in the same way.

<img src="{{ site.url }}/assets/images/jenkins-kubernetes-slaves/jenkins-freestyle-job.png" alt="docker hub configuration" style="max-height: 500px;"/>

Unfortunately with Freestyle Job (and other legacy job types) you cannot configure your Kubernetes pod per job. You're limited to the global pod templates you've pre-configured.



#### Pipeline Jobs

Similar to Freestyle jobs, running your job on the Kubernetes cluster is as simple as specifying it in the `node{}` code block

```
node('kube-slave-java') {
    # the following commands will execute in the specified docker container on your kubernetes cluster,
    sh 'echo "hello world"'
}
```




