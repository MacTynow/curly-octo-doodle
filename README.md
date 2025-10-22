# Hostaway technical assessment

## Tasks

- [x] Set up a local Kubernetes cluster using Minikube.
- [x] Use Terraform to provision the cluster with separate namespaces for internal vs external applications and any different environments.
- [x] Install ArgoCD on the cluster using Helm.
- [x] Demonstrate GitOps workflows with ArgoCD: Deploy a simple Nginx app with output "hello it's me". We should be able to deploy a new version to staging, promote it to production, rollback to any version.
- [x] Define key monitoring metrics and thresholds.

## Prerequisites 

The following should be installed on your system:
- make
- minikube
- docker
- kubectl
- helm
- terraform

The following are optional:
- argocd cli

This also assumes your kubernetes configuration is stored in `~/.kube/config`.

## Deployment

Run `make` to start the cluster, provision the namespaces and deploy ArgoCD and its workflows.

If you'd like to check that the services are running and serving traffic properly, run:
- `kubectl port-forward service/nginx-app -n stg-internal 8081:8080` for staging
- `kubectl port-forward service/nginx-app -n prd-internal 8082:8080` for production

## ArgoCD

In order to access the ArgoCD UI, run `make tunnel`, open the link in your browser after accepting the self-signed certificate, and use the credentials displayed in the terminal.
If you choose to use the cli, after starting the tunnel, run `make argocd-login` to configure it.

If an app doesn't auto-sync after a few minutes you can click the `refresh` button in the UI or refresh with the cli.

### Staging

Staging always runs the latest commit from the `main` branch in the repo. A push to that branch will auto-deploy to staging.

### Production

Promoting a version to production can be done by creating and merging a PR into the `prd` branch, or with `make promote`.

### Rollbacks 

Rollbacks can be done by reverting a PR into the `prd` branch, or with `make rollback`. This allows to follow a strict GitOps workflow.

## Cleanup 

Run `make clean` to remove all components used in this assessment.

## Monitoring

For all these metrics, I would start with an evaluation of 5 minutes unless specified otherwise to start with, and adjust as needed with time.

### App level

| Metric | Threshold | Reason |
| --- | --- | --- |
| Latency p50 | 50ms | [100ms is enough](https://www.nngroup.com/articles/powers-of-10-time-scales-in-ux/) but for such a simple app it should be much faster. This gives us direct insight in the user experience. |
| Latency p95 | 500ms | This and the below metric give us insights into outliers and the behaviour of our app under load. |
| Latency p95 | 1s |  |
| Error rate | 5% | This is more insightful than the number of requests or number of errors and also gives us visibility in user experience. I would display this on a graph with request rate as well in order to see if there are spikes. |
| CPU and memory | 80% | Correlated with other metrics this gives us extra context. |

### Cluster level

| Metric | Threshold | Reason |
| --- | --- | --- |
| CrashLoopBackOff | 3 restarts | This is a good indicator of many issues with pods and would require taking a look if it doesn't stabilise. |
| OOMs | 1 | With the above, this allows to identify quickly if there is some memory issue with an app (limits too low, scaling too slow...) |
| Pod waiting for scheduling | 5 minutes | This can show some issue with cluster capacity. |
| CPU and memory | 80% (over 15 minutes) | If the cluster usage is at this level for too long, we should consider scaling it up as we won't be able to schedule more workloads. |

### Deployment level


| Metric | Threshold | Reason |
| --- | --- | --- |
| Failed deployments | 1 | Deployments shouldn't fail. This should trigger immediate investigation (could be sync failures etc). |
| Out of sync duration | 10 minutes | The app should sync fairly quickly after a `git push`. If it's too long we should take a look at why it's not happening. |

### Notes and troubleshooting

I couldn't get the ingress addon to work on MacOS, similar issue to https://github.com/kubernetes/minikube/issues/12899, and I didn't want to have to force the user to use sudo so I decided to fallback to using plain kubectl port-forwarding instead of `minikube tunnel`.