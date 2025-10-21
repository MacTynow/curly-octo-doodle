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
- kubectl
- helm
- terraform

The following are optional:
- argocd cli

This also assumes your kubernetes configuration is stored in `~/.kube/config`.

## Deployment

Run `make` to start the cluster, provision the namespaces and deploy ArgoCD and its workflows.
In order to access the ArgoCD UI, run `make tunnel` and open the link in your browser using the credentials displayed in the terminal.

If you'd like to check that the services are running and serving traffic properly, run:
- `kubectl port-forward service/nginx-app -n stg-internal 8081:8080` for staging
- `kubectl port-forward service/nginx-app -n prd-internal 8082:8080` for production

## ArgoCD

If you choose to use the cli, after starting the tunnel, run `make argocd-login` to configure it.

### Staging

Staging always runs the latest commit from the `main` branch in the repo. A push to that branch will auto-deploy to staging.

### Production

Promoting a version to production can be done by creating and merging a PR into the `prd` branch, or with `make promote`.

### Rollbacks 

Rollbacks can be triggered from the ArgoCD UI or with the [argocd cli](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_rollback/). **Auto-sync will need to be disabled for this to work.**

The below example demonstrates a rollback with the cli.
```
> argocd app history argocd/nginx-app-staging
SOURCE  https://github.com/MacTynow/curly-octo-doodle.git
ID      DATE                           REVISION
0       2025-10-21 14:54:56 +0800 CST  main (1bdda16)
1       2025-10-21 17:47:38 +0800 CST  main (2682e24)
> argocd app set argocd/nginx-app-staging --sync-policy manual && argocd app rollback argocd/nginx-app-staging 0
TIMESTAMP                  GROUP        KIND   NAMESPACE                    NAME    STATUS   HEALTH        HOOK  MESSAGE
2025-10-21T17:50:23+08:00          ConfigMap  stg-internal          nginx-config    Synced                       
2025-10-21T17:50:23+08:00            Service  stg-internal             nginx-app    Synced  Healthy              
2025-10-21T17:50:23+08:00   apps  Deployment  stg-internal             nginx-app    Synced  Healthy              
2025-10-21T17:50:23+08:00            Service  stg-internal             nginx-app    Synced  Healthy              service/nginx-app configured
2025-10-21T17:50:23+08:00   apps  Deployment  stg-internal             nginx-app    Synced  Healthy              deployment.apps/nginx-app unchanged
2025-10-21T17:50:23+08:00          ConfigMap  stg-internal          nginx-config    Synced                       configmap/nginx-config unchanged
2025-10-21T17:50:23+08:00            Service  stg-internal             nginx-app  OutOfSync  Healthy              service/nginx-app configured

Name:               argocd/nginx-app-staging
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          stg-internal
URL:                https://argocd.example.com/applications/argocd/nginx-app-staging
Source:
- Repo:             https://github.com/MacTynow/curly-octo-doodle.git
  Target:           main
  Path:             argocd/manifests/stg
SyncWindow:         Sync Allowed
Sync Policy:        Manual
Sync Status:        OutOfSync from main (2682e24)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      1bdda16bcc5256f1f2f80cef141084ca1963937c
Phase:              Succeeded
Start:              2025-10-21 17:50:23 +0800 CST
Finished:           2025-10-21 17:50:23 +0800 CST
Duration:           0s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE     NAME          STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   stg-internal  nginx-config  Synced                    configmap/nginx-config unchanged
       Service     stg-internal  nginx-app     OutOfSync  Healthy        service/nginx-app configured
apps   Deployment  stg-internal  nginx-app     Synced     Healthy        deployment.apps/nginx-app unchanged
```

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