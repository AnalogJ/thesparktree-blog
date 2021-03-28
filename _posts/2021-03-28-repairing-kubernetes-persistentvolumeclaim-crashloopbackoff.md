---
layout: post
title: 'Repairing Kubernetes PersistentVolumeClaim - CrashLoopBackOff Errors'
date: '21-03-28T01:19:33-08:00'
cover: '/assets/images/cover_kubernetes.jpg'
subclass: 'post tag-post'
tags:
- kubernetes
- persistentvolumeclaim
- errors
- volumemount

navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

Kubernetes is an exceptionally durable piece of software, it's designed to handle failures and self-heal in most cases. However,
even them most robust software can run into issues. Which brings us to the `CrashLoopBackOff` error. A CrashloopBackOff
means that you have a pod starting, crashing, starting again, and then crashing again.

Crash loops can happen for a variety of reasons, but (in my opinion) the most difficult to fix are  CrashloopBackOff errors
associated with a corrupted PersistentVolumeClaim. In this post we'll discuss a technique you can use to safely detach
and repair a PersistentVolumeClaim, to fix a CrashloopBackOff error.

# Detach the Volume

The first step is to scale our failing deployment to 0. This is because by default PVC's have a [`ReadWriteOnce` AccessMode](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes),
meaning the volume can be mounted as read-write by a single node. If the failing pod is binding to the corrupted volume in `write` mode, then our
debugging container can't make any changes to it. Even if your PVC is `ReadWriteMany`, it's safer to ensure nothing else is writing to the volume while
wee make our repairs.

```bash
$ kubectl scale deployment failed-deployment --replicas=0
deployment.extensions "failed-deployment" scaled
```

# Debugging Pod

Next we'll need to inspect the deployment config to find the PVC identifier to repair.

```bash
$ kubectl get deployment -o jsonpath="{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}" failed-deployment
my-pvc-claim
```

Now that we know the identifier for the failing PVC, we need to create a debugging pod spec which mounts the PVC.
In this example we’ll use `busybox`, but you could use any debugging tools image here.

```yaml
# my-pvc-debugger.yaml

---
kind: Pod
apiVersion: v1
metadata:
  name: volume-debugger
spec:
  volumes:
    - name: volume-to-debug
      persistentVolumeClaim:
       claimName: <CLAIM_IDENTIFIER_HERE>
  containers:
    - name: debugger
      image: busybox
      command: ['sleep', '3600']
      volumeMounts:
        - mountPath: "/data"
          name: volume-to-debug
```

Next, lets create a new pod and run a shell inside it.

```bash
$ kubectl create -f /path/to/my-pvc-debugger.yaml
pod "volume-debugger" created
$ kubectl exec -it volume-debugger sh
/ #
```

Now that we're inside the container we can explore the volume which is mounted at `/data` and fix the issue.

# Restore Pod

Once we've repaired the PVC volume, we can exit the shell within the container and delete the debugger pod.

```bash
/ # logout
$ kubectl delete -f /path/to/my-pvc-debugger.yaml
```

Next, we'll scale our deployment back up.

```bash
$ kubectl scale deployment failed-deployment --replicas=1
deployment.extensions "failed-deployment" scaled
```

# Fin

In a perfect world we should never have to get hands on with our volumes, but occasionally bugs cause if to have to go
and clean things up. This example shows a quick way to hop into a volume for a container which does not have any user environment.

# References

- https://itnext.io/debugging-kubernetes-pvcs-a150f5efbe95
    - The guide above is a slightly modified version of Jacob Tomlinson's work. Copied for ease of reference.


