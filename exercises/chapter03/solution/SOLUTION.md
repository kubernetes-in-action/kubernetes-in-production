# Solution: Diagnosing a Broken kube-proxy

## Task 1: Confirm the symptom

```
kubectl -n api-exploration get deployment kiada
kubectl -n api-exploration get pods -l app=kiada
kubectl -n api-exploration get service kiada
kubectl -n api-exploration get endpointslices -l kubernetes.io/service-name=kiada
kubectl -n api-exploration exec netcheck -- curl -s --max-time 5 http://kiada
```

The Deployment, pods, Service, and EndpointSlice all look healthy
- two `Running`/`Ready` pods
- a ClusterIP assigned
- endpoints populated.
But the curl from `netcheck` times out.

### Why this is the right approach

Checking the Deployment, Service, and EndpointSlice before trying to
connect is what isolates the problem to the routing layer. If you
jumped straight to `curl`, and it failed, you wouldn't know whether
the pods were unhealthy, the Service had no endpoints, or something
else was wrong. Confirming each piece is correct first is what makes
"kube-proxy" a defensible diagnosis rather than a guess.

## Task 2: Diagnose the cause

```
kubectl -n kube-system get daemonset kube-proxy
kubectl -n kube-system get daemonset kube-proxy -o yaml | grep -A3 nodeSelector
kubectl get nodes --show-labels
```

The DaemonSet shows `READY 0` despite `DESIRED` matching the node count.
Its `nodeSelector` has been changed to `kubernetes.io/os: bogus-os`, which
no real node's `kubernetes.io/os` label will ever match, so the DaemonSet
controller can't schedule any pods anywhere.

### Why this is the right approach

It's tempting to jump to "kube-proxy is broken" and immediately restart or
delete its pods. But that would just fail again in a loop, since the
DaemonSet controller would refuse to reschedule them.  The root cause is
the `nodeSelector`, not the pods themselves. Reading the DaemonSet spec
and comparing it against real node labels is what identifies the fix.

## Task 3: Fix it

```
kubectl -n kube-system patch daemonset kube-proxy --type merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux"}}}}}'

kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=60s

kubectl -n api-exploration exec netcheck -- curl -s --max-time 5 http://kiada
```

Once the `nodeSelector` is fixed, the DaemonSet controller schedules a
kube-proxy pod on every node. Each pod starts watching the API server and
programs the routing rules for Services and EndpointSlices it observes,
including the `kiada` Service, since it's still there for kube-proxy to
see once it comes back up. The curl now succeeds.

## Check your work

```
./scripts/verify.sh
```

## A note on why the exercise deletes and recreates the Service

kube-proxy's programmed rules aren't torn down just because kube-proxy
itself stops running.  Once a rule is in the node's iptables, it stays
there until something explicitly changes it, so an already-existing
Service would keep routing correctly the whole time kube-proxy was
down. That's why `scripts/bootstrap.sh` (and `scripts/reset.sh`) delete
and recreate the `kiada` Service only *after* kube-proxy's pods are gone.
A brand-new Service has no rule programmed for it yet, which is the only
way to reliably reproduce this exercise's symptom.

It also means the above fix doesn't need anything to do anything beyond
restoring kube-proxy. The new kube-proxy pods perform a full sync of
every Service and EndpointSlice that exists, before starting to watch for
further changes.  They pick up the `kiada` Service, created while they
were down, as part of that sync.