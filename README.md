# DevOps Delivery Pipeline

[![Delivery pipeline](https://github.com/asad6426/devops-delivery-pipeline/actions/workflows/pipeline.yml/badge.svg)](https://github.com/asad6426/devops-delivery-pipeline/actions/workflows/pipeline.yml)

A small Python service with the release path around it: tests, a scanned container image, infrastructure as code, and a Kubernetes deployment that is upgraded, deliberately broken and rolled back on every run.

The service is intentionally simple. The delivery process is the point of this project.

## What the pipeline does

```text
test ------> image ---------------> deploy (kind cluster)
ruff         multi-stage build      terraform apply, then plan must show no drift
pytest       Trivy: fail on         kubectl apply -k
             fixable critical       upgrade v1 -> v2
             container health       broken release -> still serving
             non-root check         rollback -> serving v2
```

| Area | Implementation |
| --- | --- |
| CI/CD | [`.github/workflows/pipeline.yml`](.github/workflows/pipeline.yml) with three gated jobs |
| Container | [`Dockerfile`](Dockerfile): multi-stage build, runs as UID 10001, built-in health check |
| Infrastructure as code | [`terraform/`](terraform/): namespace, resource quota and config map |
| Kubernetes | [`k8s/`](k8s/): Deployment, Service and PodDisruptionBudget through Kustomize |
| Release testing | [`scripts/rollout_test.sh`](scripts/rollout_test.sh) |
| Monitoring | `/healthz` and Prometheus `/metrics`, with [`compose.yaml`](compose.yaml) for local Prometheus |

Pods run under the `restricted` Pod Security standard: non-root, read-only root filesystem, all capabilities dropped and the default seccomp profile.

## What a run proves

Output from the CI run, with progress lines removed:

```text
== 1. First release
deployment "delivery-api" successfully rolled out
serving version: v1 (expected v1)
== 2. Rolling upgrade to v2
deployment "delivery-api" successfully rolled out
serving version: v2 (expected v2)
== 3. Bad release: the image does not exist
error: deployment "delivery-api" exceeded its progress deadline
rollout failed as intended; ready replicas during failure: 2
serving version: v2 (expected v2)
== 4. Roll back
deployment "delivery-api" successfully rolled out
serving version: v2 (expected v2)
ALL ROLLOUT CHECKS PASSED
```

`maxUnavailable: 0` is what keeps the old replicas serving while the broken image fails to start.

An early version of this test caught a real bug. The script changed the image and the version in two commands, which created two revisions, so `rollout undo` returned to a revision that still had the broken image. Each release is now one patch and one revision.

## Limits

- The cluster is a temporary [kind](https://kind.sigs.k8s.io/) cluster inside CI, not a managed cloud service, so there is no cloud networking, ingress or load balancer here.
- Terraform uses local state and the Kubernetes provider. It does not provision cloud infrastructure.
- Images are built and loaded into the cluster directly. Nothing is pushed to a registry.
- Prometheus runs only in the local Compose file, not in the cluster.

## Run it

```bash
pip install -r requirements-dev.txt
ruff check .
python -m pytest -q
docker compose up --build
```

To run the cluster steps locally, you need Docker, kind, kubectl and Terraform. Follow the `deploy` job in the workflow file.

Built with Claude Code.
