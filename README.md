# Kubernetes in Production - Companion Code

Runnable companion code for the book, organized by chapter, plus a growing
set of interactive, self-graded exercises for any chapters that have one.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/kubernetes-in-action/kubernetes-in-production)

Codespaces will ask which container configuration to use. Every chapter
with runnable code has a plain configuration named after it that bootstraps
that chapter's `kind` cluster and starting manifests.  For the the rest
of the chapter's examples you will follow from the book. Chapters with an
interactive, self-graded exercise will have an extra configuration.

More chapters will land here over time as they're finalized in the book's source.

## Chapters

| Chapter | Code | Interactive exercise |
|---|---|---|
| 1 - From Application Deployment to Cluster Operations | *(introductory chapter, no runnable code)* | - |
| 2 - Understanding the Control Plane Components | [`code/chapter02/`](code/chapter02/) | [`exercises/chapter02/`](exercises/chapter02/) |
| 3 - Understanding the Cluster Node Components | [`code/chapter03/`](code/chapter03/) | [`exercises/chapter03/`](exercises/chapter03/) |
| 4 - Understanding the Internal Operation of Kubernetes Controllers | [`code/chapter04/`](code/chapter04/) | [`exercises/chapter04/`](exercises/chapter04/) |

See each chapter's own `bootstrap.sh` for what is automated.

## Running an interactive exercise

**In Codespaces:** click the badge above and pick the exercise's
configuration. The devcontainer installs `kubectl`, `kind`, `helm`, and
`kustomize`, then the exercise's own `scripts/bootstrap.sh` builds/loads whatever image it needs
and applies its starting manifests.

**Locally**, with Docker running:

```
cd exercises/chapter02
./scripts/bootstrap.sh
```

Then open that exercise's `EXERCISE.md`.

## Layout

```
.devcontainer/chapterNN/    One devcontainer.json per chapter.  Creates that chapter's
                            kind cluster and applies its starting manifests.
.devcontainer/<exercise>/   One devcontainer.json per interactive exercise.  All
                            devcontainer.json files install kubectl, helm, kind, and
                            kustomize via devcontainer features.
code/chapterNN/             Plain per-chapter companion code (app source, Dockerfiles,
                            Kubernetes manifests, kind cluster configs, and a
                            bootstrap.sh) straight from the book's manuscript.
exercises/<name>/           Interactive, self-graded exercises for a subset of chapters:
                            EXERCISE.md, scripts/ (bootstrap/verify/reset), solution/.
```
