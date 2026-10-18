# Solution

## Task 1: fix kube-scheduler's static pod manifest (sections 2.1 & 2.4)

```
docker exec chapter02-exercise-control-plane sed -i \
  's#/etc/kubernetes/scheduler-typo.conf#/etc/kubernetes/scheduler.conf#' \
  /etc/kubernetes/manifests/kube-scheduler.yaml

kubectl -n kube-system get pods -l component=kube-scheduler --watch
# Ctrl-C once it reads 1/1 Running

kubectl -n api-exploration get pod canary -o wide
```

### Why this is the correct fix, not just a workaround

- **The fix happens on the node, not through `kubectl`.** Static pods are
  a `kubelet` mechanism. `kubelet` reads
  `/etc/kubernetes/manifests/kube-scheduler.yaml` from local disk on a
  fixed poll/watch loop and manages whatever it finds there directly.
  There is no Deployment or ReplicaSet sitting in front of it, so
  `kubectl edit deployment kube-scheduler` isn't a thing. You have to
  reach the actual file, and in a `kind` cluster the best way is `docker exec`
  into the node container.
- **You don't need to restart anything by hand.** Editing the manifest is
  the whole fix. `kubelet` notices the file changed, tears down the old
  static pod, and starts a new one from the corrected manifest. The same
  mechanism that made the *original* change take effect within seconds
  of `bootstrap.sh` editing the file, with nothing watching for it on the
  Kubernetes API side.
- **No `FailedScheduling` event ever appeared for `canary`, and that's
  itself diagnostic.** A pod stuck `Pending` for lack of resources (like
  section 2.4.1's `resource-hungry-pod`) gets a `FailedScheduling` event
  because kube-scheduler evaluated it and rejected every node. `canary`
  got no such event because kube-scheduler wasn't running. Recognizing
  that absence is what should have pointed you at kube-scheduler rather
  than at the node's capacity.

## Task 2: confirm the fix landed in etcd (sections 2.3.1 & 2.3.2)

```
ETCD_POD=$(kubectl -n kube-system get pod -l component=etcd \
  -o jsonpath='{.items[0].metadata.name}')
ETCD_FLAGS="--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key"

kubectl -n kube-system exec "$ETCD_POD" -- etcdctl $ETCD_FLAGS endpoint health
kubectl -n kube-system exec "$ETCD_POD" -- \
  etcdctl $ETCD_FLAGS get /registry/pods/api-exploration --prefix --keys-only
```

### Why check etcd separately at all

It's tempting to treat "`kubectl get pod canary` shows `Running`" as proof
the whole control plane is healthy, but that command only proves the API
server answered. It says nothing about etcd, which is a separate process
the API server depends on but does not expose directly. Checking
`etcdctl endpoint health` and finding `canary`'s own key under
`/registry/pods/api-exploration` confirms the object you watched get
scheduled was durably persisted, not just cached somewhere in the API
server's response path.

## Check your work

```
./scripts/verify.sh
```
