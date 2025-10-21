# Hostaway technical assessment

## Tasks

- [x] Set up a local Kubernetes cluster using Minikube.
- [x] Use Terraform to provision the cluster with separate namespaces for internal vs external applications and any different environments.
- [x] Install ArgoCD on the cluster using Helm.
- [x] Demonstrate GitOps workflows with ArgoCD: Deploy a simple Nginx app with output "hello it's me". We should be able to deploy a new version to staging, promote it to production, rollback to any version.
- [ ] Define key monitoring metrics and thresholds.

## Prerequisites 

The following should be installed on your system:
- make
- minikube
- kubectl
- helm
- terraform

The following are optional:
- argocd cli

## Deployment

Run `make` to start the cluster, provision the namespaces and deploy ArgoCD and its workflows.
In order to access the ArgoCD UI, run `make tunnel` and open the link in your browser using the credentials displayed in the terminal.

## ArgoCD

Staging always runs the latest version of the app in the repo.
Promoting a version to production can be done by creating and merging a PR into the `prd` branch, or with `make promote`.
Rollbacks can be triggered from the ArgoCD UI or with the argocd cli.

## Cleanup 

Run `make clean` to remove all components used in this assessment.


### Notes

For now using port forward to access UI
Use gitops promotion: deploy all new pushes to staging, PR to prod. Rollback with PR/argocd 

Monitoring: we want monitoring on:
- cluster metrics (crashloopbackoff/pod waiting for scheduling/OOMs)
- app metrics (latency, errors, traffic)
- deployment metrics (failed deployments/rollbacks)