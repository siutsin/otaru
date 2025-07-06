# Variables
ANSIBLE_INVENTORY := ansible/inventory.yaml
INFRASTRUCTURE_DIR := infrastructure
HACK_DIR := hack

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
CYAN := \033[0;36m
MAGENTA := \033[0;35m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@echo "$(BLUE)Cluster Management:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "(setup-cluster|build-cluster|maintenance|nuke-cluster|restart-all|upgrade-cluster)" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {gsub(/\(DANGEROUS!\)/, "$(RED)(DANGEROUS!)$(NC)"); printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(MAGENTA)Development & Infrastructure:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "(generate-atlantis-yaml|clean-terragrunt-cache|update-helm-deps|delete-git-tags|clean-all)" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {gsub(/\(DANGEROUS!\)/, "$(RED)(DANGEROUS!)$(NC)"); printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Validation & Quality:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "(validate-helm-charts|check-yaml|check-markdown|lint-terraform|lint-terragrunt|test)" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Utilities:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "(status|install-deps|help)" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make <target>"
	@echo ""
	@echo "$(RED)Note:$(NC) Targets marked as DANGEROUS require explicit confirmation."
	@echo ""

define ansible_playbook
	@echo "$(GREEN)Running $(1) playbook...$(NC)"
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/playbooks/$(1).yaml
endef

# Ansible playbook targets
.PHONY: setup-cluster
setup-cluster: ## Run complete cluster setup playbook (etcd + rpi + k3s)
	$(call ansible_playbook,setup-cluster)

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
			helm lint "$$chart" --quiet || exit 1; \
		fi; \
	done
	@echo "$(GREEN)All Helm charts validated successfully!$(NC)"

.PHONY: check-yaml
check-yaml: ## Check YAML syntax in key files
	@echo "$(GREEN)Checking YAML syntax...$(NC)"
	@yq eval '.' ansible/inventory.yaml > /dev/null
	@yq eval '.' atlantis.yaml > /dev/null
	@echo "$(GREEN)YAML syntax check passed!$(NC)"

.PHONY: check-markdown
check-markdown: ## Check Markdown files with markdownlint
	@echo "$(GREEN)Checking Markdown files...$(NC)"
	@command -v markdownlint >/dev/null 2>&1 || { echo "$(YELLOW)Installing markdownlint-cli...$(NC)"; npm install -g markdownlint-cli; }
	@markdownlint "**/*.md" --ignore node_modules/
	@echo "$(GREEN)Markdown linting passed!$(NC)"

.PHONY: lint-terraform
lint-terraform: ## Lint and format Terraform files with tofu fmt
	@echo "$(GREEN)Linting Terraform files...$(NC)"
	@command -v tofu >/dev/null 2>&1 || { echo "$(RED)tofu (OpenTofu) is required but not installed.$(NC)"; exit 1; }
	@tofu fmt -recursive $(INFRASTRUCTURE_DIR) > /dev/null
	@echo "$(GREEN)Terraform linting passed!$(NC)"

.PHONY: lint-terragrunt
lint-terragrunt: ## Lint and format Terragrunt files with terragrunt hcl format
	@echo "$(GREEN)Linting Terragrunt files...$(NC)"
	@command -v terragrunt >/dev/null 2>&1 || { echo "$(RED)terragrunt is required but not installed.$(NC)"; exit 1; }
	@find $(INFRASTRUCTURE_DIR) -name "*.hcl" -type f -exec terragrunt hcl format --file={} \; > /dev/null
	@echo "$(GREEN)Terragrunt linting passed!$(NC)"

.PHONY: lint-zizmor
lint-zizmor: ## Run zizmor audit on workflows
	@echo "$(GREEN)Running zizmor audit...$(NC)"
	@zizmor --no-config . > /dev/null 2>&1 || zizmor --no-config .

.PHONY: lint-editorconfig
lint-editorconfig: ## Check .editorconfig compliance
	# Note: Excluding gateway-api and monitoring helm charts due to auto-generated CRD files with long lines
	# Excluding unifi terragrunt.hcl due to long SSH public key that cannot be safely split
	@echo "$(GREEN)Checking .editorconfig compliance...$(NC)"
	@command -v editorconfig-checker >/dev/null 2>&1 || { \
		echo "$(YELLOW)Installing editorconfig-checker...$(NC)"; \
		npm install -g editorconfig-checker; \
	}
	@editorconfig-checker -exclude "(helm-charts/(gateway-api|monitoring)/.*|infrastructure/local/lhr/unifi/terragrunt\\.hcl)" || { \
		echo "$(RED)EditorConfig violations found. Please fix manually or use your editor's .editorconfig support.$(NC)"; \
		exit 1; \
	}
	@echo "$(GREEN)EditorConfig compliance check passed!$(NC)"

.PHONY: test
test: check-yaml check-markdown validate-helm-charts lint-terraform lint-terragrunt lint-zizmor lint-editorconfig ## Run all validation and quality checks
	@echo "$(GREEN)All validation and quality checks passed!$(NC)"

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
	@command -v tofu >/dev/null 2>&1 || { echo "$(RED)tofu (OpenTofu) is required but not installed.$(NC)"; exit 1; }
	@command -v terragrunt >/dev/null 2>&1 || { echo "$(RED)terragrunt is required but not installed.$(NC)"; exit 1; }
	@echo "$(GREEN)All dependencies are installed!$(NC)"
