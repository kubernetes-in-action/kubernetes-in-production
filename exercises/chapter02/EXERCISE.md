# Control Plane Internals: Diagnosing a Crash-Looping kube-scheduler

**Companion exercise for Chapter 2 - Understanding the Control Plane
Components** (*Kubernetes in Production*). The chapter covers the components
within a healthy control plane (the API server, etcd, the scheduler, the
controller manager) with Chapter 3 explaining the static-pod mechanism that
runs them all. This exercise takes those components and breaks one of
them, so you can diagnose it the way you would in practice.

The devcontainer opens with your shell already in the  `exercises/chapter02/`
directory, where `scripts/` and `solution/` live.

## Background

`kube-scheduler`, like every other control plane component in a `kubeadm`
cluster (including the one `kind` builds for you), runs as a **static
pod**. The `kubelet` on the control-plane node reads the pod manifests
out of `/etc/kubernetes/manifests/`, runs them, and restarts them on crash
or manifest change.  There are no Deployments, no ReplicaSets, nor any API
server invocations involved in managing them. `scripts/bootstrap.sh` has already
edited `/etc/kubernetes/manifests/kube-scheduler.yaml` on the control-plane
node before you start, corrupting the `--kubeconfig` flag kube-scheduler
needs to authenticate to the API server. It then created a pod named
`canary` in the `api-exploration` namespace. Because kube-scheduler can't
run, `canary` never gets assigned to a node.

## Task 1: get `canary` scheduled again (sections 2.1 & 2.4)

1. Confirm the problem:
   ```
   kubectl -n api-exploration get pod canary
   kubectl -n api-exploration get events --field-selector=involvedObject.name=canary
   ```
   `canary` sits in `Pending`. Notice what's *missing*: no
   `FailedScheduling` event, unlike a pod that's Pending because there was
   insufficient CPU/memory (the kind of Pending the chapter's own
   `resource-hungry-pod` example in section 2.4.1 produces). That absence
   is itself a clue, a `FailedScheduling` event means kube-scheduler
   *tried* and lost; no event at all means nothing is even trying.

2. Check on kube-scheduler itself:
   ```
   kubectl -n kube-system get pods -l component=kube-scheduler
   ```
   You should see it cycling through `CrashLoopBackOff` or `Error`, with
   a climbing restart count.

3. Read its logs:
   ```
   kubectl -n kube-system logs -l component=kube-scheduler --previous
   ```
   The error will point at a kubeconfig file kube-scheduler can't open.

4. Inspect the static pod manifest directly on the node. This is the
   file kubelet is reading, not something the API server holds:
   ```
   docker exec chapter02-exercise-control-plane \
     grep kubeconfig /etc/kubernetes/manifests/kube-scheduler.yaml
   ```
   You'll see `--kubeconfig=/etc/kubernetes/scheduler-typo.conf`, a path
   that doesn't exist. The real file `kubeadm` generated is
   `/etc/kubernetes/scheduler.conf`.

5. Fix the manifest on the node:
   ```
   docker exec chapter02-exercise-control-plane sed -i \
     's#/etc/kubernetes/scheduler-typo.conf#/etc/kubernetes/scheduler.conf#' \
     /etc/kubernetes/manifests/kube-scheduler.yaml
   ```
   You don't need to restart anything by hand, the kubelet watches that
   directory and will restart the static pod on its own within a few
   seconds.

6. Confirm kube-scheduler comes back, then confirm `canary` gets
   scheduled:
   ```
   kubectl -n kube-system get pods -l component=kube-scheduler --watch
   ```
   Once it's `1/1 Running`, Ctrl-C and check:
   ```
   kubectl -n api-exploration get pod canary -o wide
   ```
   `canary` should now be `Running` with a `NODE` assigned.

## Task 2: confirm it in etcd (sections 2.3.1 & 2.3.2)

Every object in the cluster, including the Pod you just watched get
scheduled, is really just a key under `/registry/` in etcd. The API
server is the only thing allowed to talk to etcd directly, but you can
still inspect it from inside the etcd static pod itself, the same way the
chapter does.

1. Find the etcd pod and set up the same connection flags the chapter
   uses (etcd's client API requires mutual TLS, even from `localhost`):
   ```
   ETCD_POD=$(kubectl -n kube-system get pod -l component=etcd \
     -o jsonpath='{.items[0].metadata.name}')
   ETCD_FLAGS="--endpoints=https://127.0.0.1:2379 \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key"
   ```

2. Check etcd's own health, worth verifying independently rather than
   assuming "kubectl works, so everything's fine":
   ```
   kubectl -n kube-system exec "$ETCD_POD" -- etcdctl $ETCD_FLAGS endpoint health
   ```

3. Confirm `canary`'s key actually exists under `/registry/pods`:
   ```
   kubectl -n kube-system exec "$ETCD_POD" -- \
     etcdctl $ETCD_FLAGS get /registry/pods/api-exploration --prefix --keys-only
   ```
   You should see `/registry/pods/api-exploration/canary` in the list.
   (The value itself is stored as protobuf, not JSON, which is why the
   chapter and this exercise both stick to `--keys-only` rather than
   trying to print it directly.)

## Check your work

Run the verify script from the `exercises/chapter02/` directory:

```
./scripts/verify.sh
```

## Hints

- Static pods are managed by `kubelet` reading a directory on disk, not
  by the API server, so `kubectl edit`/`kubectl apply` won't touch them.
  You have to reach the node itself, which is why every fix command here
  goes through `docker exec` rather than `kubectl`.
- `kubectl logs --previous` gets you the logs of the *last* crashed
  container, which is what you want for a pod that's already restarted
  by the time you look at it.
- Stuck, or want to compare notes? `cat solution/SOLUTION.md`.
- Want to try again from scratch? `./scripts/reset.sh`.