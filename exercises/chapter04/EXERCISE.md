# Chapter 4 Exercise: The Orphaned Pod

**Companion exercise for Chapter 4 - Understanding the Internal Operation
of Kubernetes Controllers (*Kubernetes in Production*).  This exercise
covers the content in section 4.2.1, the ownership chain between a Deployment,
its ReplicaSet, and the pods it manages.

The devcontainer opens with your shell already in the  `exercises/chapter04/`
directory, where `scripts/` and `solution/` live.

## Background

A ReplicaSet doesn't track "its" pods by any stored list of names or UIDs.
It tracks them purely by **label selector**.  Any pod in the same namespace,
whose labels match `spec.selector`, counts toward the ReplicaSet's replica
total.  It doesn';t matter who created it nor when. The `ownerReferences`
field you see on a managed pod, pointing back at the ReplicaSet, is a record
that the controller noticed a match and adopted the pod. It isn't necessarily
the mechanism that produced the match in the first place.

This cuts both ways:

- Patch a stray pod's labels to *match* a ReplicaSet's selector, and the
  controller adopts it (adds an `ownerReference`) and counts it toward the
  total, even though it never created that pod.
- Patch one of a ReplicaSet's own pods so its labels *no longer* match the
  selector, and the controller does two things almost immediately. It
  releases that pod (strips the `ownerReference`, since the pod is no longer
  "its" pod), and it creates a brand new pod to bring the matching count back
  up to the desired replica count.

The released pod isn't cleaned up automatically. It keeps running,
completely unmanaged, consuming resources, until something else notices
and deletes it.

## Task 1: Confirm the symptom

1. Check the Deployment's own status:
   ```
   kubectl -n api-exploration get deployment webapp
   ```
   It reports `3/3` ready replicas.  If we only check this number, then
   everything looks healthy.

2. Now compare the *total* pod count in the namespace against the count
   that actually matches the Deployment's label:
   ```
   kubectl -n api-exploration get pods
   kubectl -n api-exploration get pods -l app=webapp
   ```
   The unfiltered list has one more pod than the filtered one.

## Task 2: Diagnose the cause

1. Show every pod's labels and spot the odd one out:
   ```
   kubectl -n api-exploration get pods --show-labels
   ```

2. Confirm that pod is really unmanaged, not just configured with different labels:
   ```
   kubectl -n api-exploration get pod <pod-name> \
     -o jsonpath='{.metadata.ownerReferences}'
   ```
   Empty output means no controller owns this pod, it's an orphan and will
   sit there indefinitely. Nothing is watching it or going to clean it up.

## Task 3: Fix it

Delete the orphaned pod:

```
kubectl -n api-exploration delete pod <pod-name>
```

Confirm the namespace is back to exactly 3 pods, all matching `app=webapp`:

```
kubectl -n api-exploration get pods
kubectl -n api-exploration get pods -l app=webapp
```

## Check your work

Run the verify script:

```
./scripts/verify.sh
```

It checks that the namespace has exactly 3 pods, that all 3 match
`app=webapp`, that none of them are missing an `ownerReference`, and that
the Deployment still reports 3/3 ready.

## Hints

- Stuck, or want to compare notes? `cat solution/SOLUTION.md`.
- Want to try again from scratch? Run `./scripts/reset.sh`.