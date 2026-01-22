.PHONY: help up down status check bootstrap clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Create k3d cluster and install FluxCD
	./setup-cluster.sh

down: ## Delete k3d cluster
	./teardown-cluster.sh

status: ## Check cluster and Flux status
	@echo "📊 Cluster Status:"
	@kubectl get nodes
	@echo ""
	@echo "🔧 Flux Components:"
	@kubectl -n flux-system get pods
	@echo ""
	@echo "📦 Flux Resources:"
	@flux get all

check: ## Run Flux checks
	flux check

bootstrap: ## Bootstrap Flux (requires GITHUB_TOKEN or GITLAB_TOKEN)
	@if [ -n "$$GITHUB_TOKEN" ]; then \
		flux bootstrap github --owner=$${GITHUB_OWNER} --repository=$${GITHUB_REPO} --branch=main --path=clusters/fluxcd-platform --personal; \
	elif [ -n "$$GITLAB_TOKEN" ]; then \
		flux bootstrap gitlab --owner=$${GITLAB_OWNER} --repository=$${GITLAB_REPO} --branch=main --path=clusters/fluxcd-platform; \
	else \
		echo "❌ Set GITHUB_TOKEN or GITLAB_TOKEN environment variable"; exit 1; \
	fi

logs: ## Tail Flux logs
	flux logs --all-namespaces --follow

reconcile: ## Force reconcile all Flux resources
	flux reconcile source git flux-system
	flux reconcile kustomization flux-system

clean: down ## Alias for down
