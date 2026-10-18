# Chapter 3 Exercise: Diagnosing a Broken kube-proxy

**Companion exercise for Chapter 3 - Understanding the Cluster Node
Components** (*Kubernetes in Production*).  This exercise covers the
content in section 3.4, how Services get their ClusterIP routed.
kube-proxy watches Services and EndpointSlices, then programs the
routing rules forwarding the traffic sent to a Service's ClusterIP
on to one of its pods.

The devcontainer opens with your shell already in the  `exercises/chapter03/`
directory, where `scripts/` and `solution/` live.

## Background

`kube-proxy` runs as a DaemonSet in the `kube-system` namespace, one pod per
node. Each kube-proxy pod watches the API server for Services and
EndpointSlices and programs matching NAT rules into the node's kernel (by
default, iptables). This means:

- A Pod's own IP is reachable directly regardless of kube-proxy.  This is
  handled by the CNI.
- A Service name still resolves via DNS regardless of kube-proxy.  CoreDNS
  watches the API server directly and doesn't depend on kube-proxy.
- But connecting to a Service's ClusterIP depends entirely on kube-proxy
  having programmed the right rule on the node you're connecting from.

Critically, kube-proxy pods are stateless across restarts.  Each pod does a
full sync of every Service and EndpointSlice that exists before it starts
watching for further changes. A Service created while kube-proxy was down
still gets picked up the moment kube-proxy comes back, with nothing extra
needed.

## Task 1: Confirm the symptom

The exercise bootstrap has deployed a `kiada` Deployment (2 replicas) and a
`kiada` Service in the `api-exploration` namespace, plus a `netcheck` pod
you can use as a test client. Confirm the Service is broken:

1. Check the Deployment and its pods are healthy:
   ```
   kubectl -n api-exploration get deployment kiada
   kubectl -n api-exploration get pods -l app=kiada
   ```
   Both replicas should show `Running` and `Ready`.

2. Check the Service and its EndpointSlice look correct:
   ```
   kubectl -n api-exploration get service kiada
   kubectl -n api-exploration get endpointslices -l kubernetes.io/service-name=kiada
   ```
   The EndpointSlice should list both pod IPs as ready endpoints.

3. Now try to actually reach the Service from inside the cluster:
   ```
   kubectl -n api-exploration exec netcheck -- curl -s --max-time 5 http://kiada
   ```
   This should time out or fail to connect, even though everything above
   looks healthy.

## Task 2: Diagnose the cause

1. Check kube-proxy's DaemonSet status:
   ```
   kubectl -n kube-system get daemonset kube-proxy
   ```
   Look at `DESIRED`, `CURRENT`, and `READY`. If `READY` is `0`, no kube-proxy pod
   is actually running anywhere.

2. Find out why none are scheduled:
   ```
   kubectl -n kube-system get daemonset kube-proxy -o yaml | grep -A3 nodeSelector
   ```
   Compare this to the nodes' actual labels:
   ```
   kubectl get nodes --show-labels
   ```

3. You should find the DaemonSet's `nodeSelector` no longer matches any
   node in the cluster, which is why every kube-proxy pod was evicted and
   none could be rescheduled.

## Task 3: Fix it

1. Patch the DaemonSet's `nodeSelector` back to something every node
   actually matches:
   ```
   kubectl -n kube-system patch daemonset kube-proxy --type merge \
     -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux"}}}}}'
   ```

2. Wait for kube-proxy to roll out to every node:
   ```
   kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=60s
   ```

3. Confirm the Service works now:
   ```
   kubectl -n api-exploration exec netcheck -- curl -s --max-time 5 http://kiada
   ```
   You should get back the kiada app's HTML response.

## Check your work

Run the verify script:

```
./scripts/verify.sh
```

It checks that kube-proxy's `nodeSelector` is restored, that the DaemonSet
is fully scheduled and Ready on every node, and that a curl to the Service
from inside the cluster actually succeeds.

## Hints

- Stuck, or want to compare notes? `cat solution/SOLUTION.md`.
- Want to try again from scratch? Run `./scripts/reset.sh`.