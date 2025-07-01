# Variables
ANSIBLE_INVENTORY := ansible/inventory.yaml
INFRASTRUCTURE_DIR := infrastructure
HACK_DIR := hack

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make <target>"
	@echo ""

# Ansible playbook pattern rule
define ansible_playbook
	@echo "$(GREEN)Running $(1) playbook...$(NC)"
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/playbooks/$(1).yaml
endef

# Ansible playbook targets
.PHONY: main
main: ## Run main ansible playbook
	$(call ansible_playbook,main)

.PHONY: maintenance
maintenance: ## Run maintenance ansible playbook
	$(call ansible_playbook,maintenance)

.PHONY: upgrade-cluster
upgrade-cluster: ## Run cluster upgrade playbook
	$(call ansible_playbook,upgrade-cluster)

.PHONY: nuke-cluster
nuke-cluster: ## Run cluster destruction playbook (DANGEROUS!)
	@echo "$(RED)WARNING: This will destroy the cluster!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	$(call ansible_playbook,nuke-cluster)

.PHONY: build-cluster
build-cluster: ## Run cluster build playbook
	$(call ansible_playbook,build-cluster)

.PHONY: restart-all
restart-all: ## Run restart all services playbook
	$(call ansible_playbook,restart-all)

# Infrastructure and development targets
.PHONY: generate-atlantis-yaml
generate-atlantis-yaml: ## Generate Atlantis configuration file
	@echo "$(GREEN)Generating Atlantis configuration...$(NC)"
	bash $(HACK_DIR)/generate-atlantis-yaml.sh

.PHONY: clean-terragrunt-cache
clean-terragrunt-cache: ## Clean up all .terragrunt-cache folders in infrastructure directory
	@echo "$(GREEN)Cleaning Terragrunt cache...$(NC)"
	bash $(HACK_DIR)/remove-terragrunt-cache.sh $(INFRASTRUCTURE_DIR)

.PHONY: update-helm-deps
update-helm-deps: ## Update all Helm chart dependencies
	@echo "$(GREEN)Updating Helm dependencies for all charts...$(NC)"
	@echo "$(YELLOW)This may take a few minutes...$(NC)"
	bash $(HACK_DIR)/update-all-helm-dependency.sh
	@echo "$(GREEN)Helm dependencies updated successfully!$(NC)"

.PHONY: delete-git-tags
delete-git-tags: ## Delete all Git tags (DANGEROUS!)
	@echo "$(RED)WARNING: This will delete ALL Git tags both locally and remotely!$(NC)"
	@echo "$(RED)This action cannot be undone!$(NC)"
	@read -p "Are you absolutely sure? Type 'DELETE ALL TAGS' to continue: " confirm && [ "$$confirm" = "DELETE ALL TAGS" ]
	@echo "$(YELLOW)Deleting all Git tags...$(NC)"
	bash $(HACK_DIR)/delete-git-tags.sh
	@echo "$(GREEN)All Git tags have been deleted!$(NC)"

.PHONY: clean-all
clean-all: clean-terragrunt-cache ## Clean all temporary files and caches
	@echo "$(GREEN)Cleaning all temporary files...$(NC)"
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@find . -name "*.log" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

# Validation and linting targets
.PHONY: validate-helm-charts
validate-helm-charts: ## Validate all Helm charts
	@echo "$(GREEN)Validating Helm charts...$(NC)"
	@for chart in helm-charts/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Validating $$(basename $$chart)..."; \
			helm lint "$$chart" || exit 1; \
		fi; \
	done
	@echo "$(GREEN)All Helm charts validated successfully!$(NC)"

.PHONY: check-yaml
check-yaml: ## Check YAML syntax in key files
	@echo "$(GREEN)Checking YAML syntax...$(NC)"
	@yq eval '.' ansible/inventory.yaml > /dev/null
	@yq eval '.' atlantis.yaml > /dev/null
	@echo "$(GREEN)YAML syntax check passed!$(NC)"

# Utility targets
.PHONY: status
status: ## Show current project status
	@echo "$(GREEN)Project Status:$(NC)"
	@echo "  Infrastructure directory: $(INFRASTRUCTURE_DIR)"
	@echo "  Ansible inventory: $(ANSIBLE_INVENTORY)"
	@echo "  Helm charts: $$(find helm-charts -name "Chart.yaml" | wc -l | tr -d ' ') found"
	@echo "  Terragrunt cache dirs: $$(find $(INFRASTRUCTURE_DIR) -name ".terragrunt-cache" 2>/dev/null | wc -l | tr -d ' ') found"

.PHONY: install-deps
install-deps: ## Install development dependencies
	@echo "$(GREEN)Installing development dependencies...$(NC)"
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)Helm is required but not installed.$(NC)"; exit 1; }
	@command -v yq >/dev/null 2>&1 || { echo "$(RED)yq is required but not installed.$(NC)"; exit 1; }
	@command -v ansible-playbook >/dev/null 2>&1 || { echo "$(RED)Ansible is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)All dependencies are installed!$(NC)"
