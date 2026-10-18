# Solution: The Orphaned Pod

## Task 1: Confirm the symptom

```
kubectl -n api-exploration get deployment webapp
kubectl -n api-exploration get pods
kubectl -n api-exploration get pods -l app=webapp
```

The Deployment reports `3/3` ready replicas. The unfiltered pod list shows
4 pods, but the list filtered on `app=webapp` shows only 3.  There is an
extra pod in the namespace that the Deployment's label selector doesn't
see.

### Why this is the right approach

Deployment/ReplicaSet status fields (`READY`, `AVAILABLE`) only ever count
pods that match the selector.  They will never match an *extra*,
non-matching pod sitting in the same namespace. The only way to notice an
extra pod exists is to compare the namespace's actual pod count against the
selector-filtered count. Trusting only `kubectl get deployment` would miss
this scenario.

## Task 2: Diagnose the cause

```
kubectl -n api-exploration get pods --show-labels
kubectl -n api-exploration get pod <pod-name> -o jsonpath='{.metadata.ownerReferences}'
```

One pod carries `app=webapp-drifted` instead of `app=webapp`. Its
`ownerReferences` field is empty, as no controller claims it.

### Why this is the right approach

Finding a pod with a different label isn't by itself proof that it's
unmanaged, in theory something else could own a pod with that label.
Checking `ownerReferences` is what confirms the pod is definitely
orphaned, rather than just labelled differently and someone else's
responsibility.

## Task 3: Fix it

```
kubectl -n api-exploration delete pod <pod-name>
```

Deleting the orphan is the right fix here because nothing owns it,
there's no controller to hand it back to.  Keeping an unmanaged pod
around means it will never get rolled when the Deployment's pod template
changes, never get replaced if it crashes, and never get counted by
anything watching `app=webapp`.

An alternative would be to relabel the pod back to `app=webapp`,
instead of deleting it. The ReplicaSet controller will adopt it again,
since it's just applying the same selector match, but now it will see
4 pods matching a ReplicaSet whose desired count is 3.  The controller
will delete one of the four to correct the surplus, but which of the
four that gets chosen for deletion is not something you would control.
Choosing to delete the pod you have already identified as the orphan
is the more predictable fix.

### Why both fixes lead to the same outcome

Both fixes converge on the same end state (3 pods, all matching, all
owned) because both work through the same mechanism.  The ReplicaSet
controller will reconcile toward "N pods matching my selector," not
toward a particular set of pod identities.

## Check your work

```
./scripts/verify.sh
```