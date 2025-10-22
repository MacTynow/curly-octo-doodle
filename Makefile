.PHONY: all start stop delete setup check-minikube check-terraform terraform-init terraform-apply terraform-destroy check-helm helm-install helm-delete check-argocd \
	promote register-apps argocd-login tunnel build

CLUSTER_NAME = hostaway
CPUS ?= 2
MEMORY ?= 4096
DRIVER ?= docker
KUBERNETES_VERSION ?= stable

all: setup terraform-run helm-install register-apps

start:
	minikube start \
		--cpus=$(CPUS) \
		--memory=$(MEMORY) \
		--driver=$(DRIVER) \
		--kubernetes-version=$(KUBERNETES_VERSION) \
		-p $(CLUSTER_NAME)

stop:
	minikube stop -p $(CLUSTER_NAME)

delete:
	minikube delete -p $(CLUSTER_NAME)

setup: check-minikube start
	@echo "Cluster $(CLUSTER_NAME) is ready"

check-minikube:
	@which minikube > /dev/null || (echo "minikube not found. Install from https://minikube.sigs.k8s.io/docs/start/" && exit 1)

check-terraform:
	@which terraform > /dev/null || (echo "terraform not found. Install from https://developer.hashicorp.com/terraform/install" && exit 1)

check-helm:
	@which helm > /dev/null || (echo "helm not found. Install from https://helm.sh/docs/intro/install/" && exit 1)

check-argocd:
	@which argocd > /dev/null || (echo "argocd not found. Install from https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli" && exit 1)

terraform-init:
	@terraform init

terraform-run: check-terraform terraform-init
	@terraform apply --auto-approve

terraform-destroy:
	@terraform destroy --auto-approve

helm-install: terraform-run
	@helm repo add argo https://argoproj.github.io/argo-helm
	@helm install argocd argo/argo-cd --namespace argocd --values argocd/values.yaml

helm-delete:
	@helm delete argocd --namespace argocd

tunnel:
	@echo "Access ArgoCD UI at https://localhost:8080"
	@echo "User: admin | Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@kubectl port-forward service/argocd-server -n argocd 8080:443

register-apps:
	@kubectl apply -f argocd/app-stg.yaml
	@kubectl apply -f argocd/app-prd.yaml

promote:
	@if [ "$$(git branch --show-current)" != "main" ]; then \
			echo "Error: Must be on main branch to promote"; \
			exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: You have uncommitted changes. Commit or stash them first."; \
		exit 1; \
	fi
	@if [ "$$(git rev-parse @)" != "$$(git rev-parse @{u})" ]; then \
		echo "Error: Current branch is not pushed to remote. Push first."; \
		exit 1; \
	fi
	@echo "Promoting $$(git rev-parse HEAD) to production..."
	@git checkout prd
	@git pull --ff-only
	@git merge main
	@git push origin prd
	@git checkout main
	@echo "✓ Successfully promoted to production!"

argocd-login:
	@argocd login localhost:8080 --insecure --username admin --password $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

build:
	@echo "Building application image..."
	@cd app && docker build -t hostaway/nginx-app:latest .
	@echo "✓ Image built: hostaway/nginx-app:latest"

clean: terraform-destroy delete

