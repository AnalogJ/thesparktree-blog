---
layout: post
title: Step-By-Step Shipyard 2 Docker Cluster
date: '2015-07-16T21:11:15-07:00'
cover: '/assets/images/cover_docker.jpg'
subclass: 'post tag-post'
tags:
- devops
- docker
- shipyard-project
- cluser
redirect_from:
- /post/124285589139/step-by-step-shipyard-2-docker-cluster
- /post/124285589139
disqus_id: 'https://blog.thesparktree.com/post/124285589139'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'
---

# Step-By-Step Shipyard 2 Docker Cluster

Since [Shipyard 3](https://github.com/shipyard/shipyard/pull/455) (with its built in support for [Docker Swarm](https://github.com/docker/swarm)) is not quite ready, I thought I would create a step-by-step guide for getting a Shipyard 2 cluster going with 3 nodes (engines).

I've seen a few other guides written, but they are either dated or missing very important instructions.

# Requirements

This guide makes a few assumtions about your setup. Since we're going to be creating a cluster, you'll need more than 2 servers available to run as nodes. This guide will have __3 servers running as nodes, and 1 dedicated master server__. You should also have the latest version of [docker installed on all your servers](https://docs.docker.com/installation/) (master and nodes) as of right now, that is __Docker 1.7__. This guide is written to be used with Ubuntu 14.04 but should work on any linux system with little to no changes.

# Definitions

In the following guide, I'll make use of the following variables. If you see them in any instruction you should replace it with the applicable value

- __$MASTER_HOSTNAME__ - the DNS name/IP Addresss of your Shipyard master server
- __$NODE1_HOSTNAME__ - the DNS name/IP Addresss of your Shipyard node1 server
- __$NODE2_HOSTNAME__ - the DNS name/IP Addresss of your Shipyard node2 server
- __$NODE3_HOSTNAME__ - the DNS name/IP Addresss of your Shipyard node3 server

# Security Configuration

As recommended by the [Docker Security Guide](https://docs.docker.com/articles/security/) we're going to want to [Protect the Docker daemon socket](https://docs.docker.com/articles/https/) as Shipyard will need to remotely access the Docker daemon on each node. Don't worry about blindly following those instructions. All the relavent steps are included below with descriptions and a few tweaks to get everything working for a Shipyard cluster.

> By default, Docker runs via a non-networked Unix socket. It can also optionally communicate using a HTTP socket.
> If you need Docker to be reachable via the network in a safe manner, you can enable TLS by specifying the tlsverify flag and pointing Docker’s tlscacert flag to a trusted CA certificate.

At the end of this section we'll have protected the Docker daemon on each of our servers such that it will only allow connections from clients authenticated by a certificate signed by that CA. We can then provide Shipyard with the connection information and associated client certificates so that Shipyard can securely communicate with the Docker daemons on the nodes.

Here’s a quick rundown of what we’re going to be doing:

- Create a minimal openssl.cnf file with required settings
- Create a Certificate Authority keypair
- Use the CA to create a keypair for each of your Nodes
- Transfer the keys to the correct nodes
- Configure the Docker daemon on the Nodes to use TLS by default
- Setup IPTables firewall rules

## Create a minimal openssl.cnf file on Master

```
$ ssh root@$MASTER_HOSTNAME
$ nano /etc/docker/openssl.cnf

[ req ]
default_bits	= 4096
default_keyfile = privkey.pem
distinguished_name	= req_distinguished_name
x509_extensions	= v3_ca
default_md = sha1
string_mask = nombstr
req_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = US
stateOrProvinceName = CA
localityName = San Francisco
organizationName = SparkTree Inc
organizationalUnitName	= Shipyard
emailAddress = jason@thesparktree.com

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth,serverAuth
subjectKeyIdentifier = hash

[ v3_ca ]
subjectKeyIdentifier	= hash
authorityKeyIdentifier	= keyid:always,issuer:always
basicConstraints = CA:true

[ crl_ext ]
authorityKeyIdentifier=keyid:always
```

## Create a Certificate Authority keypair on Master

First generate CA private and public keys:

```bash
$ cd /etc/docker/
$ openssl genrsa -aes256 -out ca-key.pem 2048
$ openssl req -config openssl.cnf -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem
```

In order to protect your keys from accidental damage, you will want to remove their write permissions.

```bash
$ chmod -v 0400 ca-key.pem
$ chmod -v 0444 ca.pem
```

## Use the CA to create a keypair for your Nodes on Master

Now that we have a CA, you can create a server key and certificate signing request (CSR) for each Node. We'll create individual folders to contain the server and client key pairs for each Node

```bash
$ mkdir /etc/docker/node1
$ mkdir /etc/docker/node2
$ mkdir /etc/docker/node3
```

Make sure that “Common Name” (i.e., server FQDN or YOUR name) matches the hostname you will use to connect to your __Node1__:

```bash
$ cd /etc/docker/node1
$ openssl genrsa -out server-key.pem 2048
$ openssl req -subj "/CN=$NODE1_HOSTNAME" -new -key server-key.pem \
-out server.csr
```

Next, we’re going to sign the __Node1__ public key with our CA:

```bash
$ openssl x509 -req -days 3650 -in server.csr -CA /etc/docker/ca.pem -CAkey /etc/docker/ca-key.pem \
-CAcreateserial -out server-cert.pem -extensions v3_req -extfile /etc/docker/openssl.cnf
```

For the Shipyard master to communicate with __Node1__ using client authentication we'll need to create a client key and certificate signing request:

```bash
$ openssl genrsa -out key.pem 2048
$ openssl req -subj '/CN=node1_client' -new -key key.pem -out client.csr
```

Then sign the __Node1__ client key as we did the server key.

```bash
$ openssl x509 -req -days 3650 -in client.csr -CA /etc/docker/ca.pem -CAkey /etc/docker/ca-key.pem \
-CAcreateserial -out cert.pem -extensions v3_req -extfile /etc/docker/openssl.cnf
```

After generating cert.pem and server-cert.pem for __Node1__ you can safely remove the two certificate signing requests:

	$ rm -v client.csr server.csr

In order to protect your keys from accidental damage, you will want to remove their write permissions. To make them only readable by you, change file modes as follows:

	$ chmod -v 0400 key.pem server-key.pem

Now that we have a server and client key pair for __Node1__ we have to follow the above instructions 2 more times, for __Node2__ and __Node3__ inside their respective folders.

## Transfer the keys to the correct nodes

Now that we have all the key pairs that we need for each Node, we need to move them to the correct servers.

```bash
$ cd /etc/docker/node1 && \
scp /etc/docker/ca.pem server-cert.pem server-key.pem root@$NODE1_HOSTNAME:/etc/docker/

$ cd /etc/docker/node2 && \
scp /etc/docker/ca.pem server-cert.pem server-key.pem root@$NODE2_HOSTNAME:/etc/docker/

$ cd /etc/docker/node3 && \
scp /etc/docker/ca.pem server-cert.pem server-key.pem root@$NODE3_HOSTNAME:/etc/docker/
```

## Configure the Docker daemon on the Nodes to use TLS by default

Now that the server key pairs have been copied to the Nodes, we need to configure Docker to use them. First lets stop the Docker daemon on the Node.

```bash
$ ssh root@$NODE1_HOSTNAME
$ service docker stop
```

Update your Docker daemon settings to use TLS. I’m using Ubuntu so my file is at `/etc/default/docker`.

	$ nano /etc/default/docker

And add the following line to the bottom of the file.

	DOCKER_OPTS="--tlsverify -H=unix:///var/run/docker.sock -H=$NODE1_HOSTNAME:2376 --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem --label name=node1"

Now we can restart the Docker daemon on the Node

	$ service docker start

Now follow the above instructions for __Node2__ and __Node3__ by replacing all instances of `node1` and `$NODE1_HOSTNAME` with the appropriate Node variables.

## Setup IPTables firewall rules

	TODO

# Shipyard Configuration

Now that the Nodes are all correctly configured, its time to [deploy Shipyard on the Master](http://shipyard-project.com/docs/quickstart/). There is a very small Docker image that will deploy and manage an entire Shipyard stack called Deploy.

``` bash
$ ssh root@$MASTER_HOSTNAME
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
shipyard/deploy start
```

Once that's complete lets also deploy the Shipyard CLI container

	$ docker run -it --rm shipyard/shipyard-cli shipyard help

You should now be able to access your Shipyard web UI by visiting  `http://$MASTER_HOSTNAME:8080` and logging in with:

	username: admin
	password: shipyard

## Register Nodes as Shipyard Engines

Now that we have a working Shipyard container, lets register our Nodes as Shipyard Engines, after logging into the Shipyard CLI.

```
$ docker run -it -v /etc/docker/:/home/  shipyard/shipyard-cli
shipyard cli> shipyard login
URL:http://$MASTER_HOSTNAME:8080
Username: admin
Password: shipyard
```

Before we do anything lets change the insecure default Shipyard Admin account password

```
shipyard cli> shipyard change-password
Password: <enter a new password>
Confirm: <re-enter a new password>
```

Now lets register our Nodes

```
shipyard cli> shipyard add-engine --id node1 \
--addr https://$NODE1_HOSTNAME:2376 \
--label node1 \
--ssl-cert /home/node1/cert.pem \
--ssl-key /home/node1/key.pem \
--ca-cert /home/ca.pem \
--cpus 4.0 \
--memory 2048

shipyard cli> shipyard add-engine --id node2 \
--addr https://$NODE2_HOSTNAME:2376 \
--label node2 \
--ssl-cert /home/node2/cert.pem \
--ssl-key /home/node2/key.pem \
--ca-cert /home/ca.pem \
--cpus 4.0 \
--memory 2048

shipyard cli> shipyard add-engine --id node3 \
--addr https://$NODE3_HOSTNAME:2376 \
--label node3 \
--ssl-cert /home/node3/cert.pem \
--ssl-key /home/node3/key.pem \
--ca-cert /home/ca.pem \
--cpus 4.0 \
--memory 2048
```

Once the operation is complete, use ctrl+d to exit the CLI.

# Fin

At this point you should have a working Shipyard Cluster. You should now be able to view and manage all containers deployed on your various Nodes under the Containers tab:


![Containers](https://www.ovh.com/us/images/guides/1762/img_2614.jpg)

# References

- https://docs.docker.com/installation/
- https://docs.docker.com/articles/security/
- https://docs.docker.com/articles/https/
- http://www.blackfinsecurity.com/docker-swarm-with-tls-authentication/
- https://askubuntu.com/questions/147241/execute-sudo-without-password
- http://sheerun.net/2014/05/17/remote-access-to-docker-with-tls/
- https://www.ovh.com/us/g1762.orchestrating_a_cluster_of_docker_servers_with_shipyard </re-enter></enter>
