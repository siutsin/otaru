# Variables
ANSIBLE_INVENTORY := ansible/inventory.yaml
INFRASTRUCTURE_DIR := infrastructure
HACK_DIR := hack
OUTPUT_FILE ?= otaru-architecture
LUKS_UNLOCK_PORT ?= 1024
LUKS_UNLOCK_HOST_QUERY := \
	[(.all.children[]?.hosts? // {}) | to_entries[] | \
	select(.key == strenv(TARGET) or .key == (strenv(TARGET) + ".local") or \
	.value.ansible_host == strenv(TARGET)) | .value.ansible_host][0] // \
	strenv(TARGET)

ifneq (,$(filter unlock luks,$(MAKECMDGOALS)))
ifneq ($(word 2,$(MAKECMDGOALS)),)
override NODE_TARGET := $(word 2,$(MAKECMDGOALS))
.PHONY: $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)):
	@:
endif
endif

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
		grep -E "^(setup|luks|maintenance|restart|nuke|upgrade):" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {gsub(/\(DANGEROUS!\)/, "$(RED)(DANGEROUS!)$(NC)"); printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(MAGENTA)Development & Infrastructure:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "^(atlantis|clean-terragrunt-cache|update-helm-deps|delete-git-tags|clean-all|generate-diagrams):" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {gsub(/\(DANGEROUS!\)/, "$(RED)(DANGEROUS!)$(NC)"); printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Validation & Quality:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "^(validate-helm-charts|check-yaml|check-markdown|lint-terraform|lint-terragrunt|lint-zizmor|lint-editorconfig|validate-argocd-manifest|format-python|test):" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Utilities:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -E "^(status|install-deps|unlock|help):" | \
		sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make <target>"
	@echo ""
	@echo "$(RED)Note:$(NC) Targets marked as DANGEROUS require explicit confirmation."
	@echo ""

define ansible_playbook
	@echo "$(GREEN)Running $(1) playbook...$(NC)"
	ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -v -i $(ANSIBLE_INVENTORY) $(if $(CHANNEL),-e K3S_CHANNEL=$(CHANNEL),) ansible/playbooks/$(1).yaml
endef

# Ansible playbook targets
.PHONY: setup
setup: ## Configure Raspberry Pi nodes and k3s cluster (assumes FDE state already exists)
	$(call ansible_playbook,setup)

.PHONY: luks
luks: ## Rebuild one node into a clean encrypted-root state from rescue (usage: make luks raspberrypi-02)
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "$(RED)Usage: make luks <node-name> EXPECTED_DISK_MODEL_SUBSTRING=<model> [LUKS_PASSWORD_FILE=/path]$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$(EXPECTED_DISK_MODEL_SUBSTRING)" ]; then \
		echo "$(RED)Set EXPECTED_DISK_MODEL_SUBSTRING to a stable substring for the target NVMe model.$(NC)"; \
		exit 1; \
	fi
	@target="$(NODE_TARGET)"; \
	host="$$(TARGET="$$target" yq -r '$(LUKS_UNLOCK_HOST_QUERY)' $(ANSIBLE_INVENTORY))"; \
	echo "$(RED)WARNING: This will wipe and rebuild $$target at $$host into a clean LUKS root state.$(NC)"; \
	read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	@target="$(NODE_TARGET)"; \
	host="$$(TARGET="$$target" yq -r '$(LUKS_UNLOCK_HOST_QUERY)' $(ANSIBLE_INVENTORY))"; \
	echo "$(GREEN)Rebuilding $$target ($$host) into clean encrypted-root state...$(NC)"; \
	ANSIBLE_CONFIG=ansible/ansible.cfg \
	LUKS_PASSWORD_FILE="$(LUKS_PASSWORD_FILE)" \
	OTARU_LUKS_PASSWORD="$(OTARU_LUKS_PASSWORD)" \
	ansible-playbook -v -i $(ANSIBLE_INVENTORY) \
		-e target_node="$$target" \
		-e expected_disk_model_substring="$(EXPECTED_DISK_MODEL_SUBSTRING)" \
		ansible/playbooks/luks.yaml

.PHONY: maintenance
maintenance: ## Update packages, rolling reboot, and restart workloads
	$(call ansible_playbook,maintenance)

.PHONY: restart
restart: ## Restart all workloads without updating packages
	$(call ansible_playbook,restart)

.PHONY: upgrade
upgrade: ## Run cluster upgrade playbook (e.g., make upgrade CHANNEL=latest)
	$(call ansible_playbook,upgrade)

.PHONY: nuke
nuke: ## Run cluster destruction playbook (DANGEROUS!)
	@echo "$(RED)WARNING: This will destroy the cluster!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	$(call ansible_playbook,nuke)

# Infrastructure and development targets
.PHONY: atlantis
atlantis: ## Generate Atlantis configuration file
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

.PHONY: poetry-install
poetry-install:
	@echo "$(GREEN)Ensuring poetry dependencies are installed...$(NC)"
	@cd diagrams && poetry sync && cd ..

.PHONY: generate-diagrams
generate-diagrams: poetry-install format-python ## Generate architecture diagrams (OUTPUT_FILE=filename to override)
	@echo "$(GREEN)Generating architecture diagrams...$(NC)"
	@mkdir -p assets
	@cd diagrams && poetry run python otaru-architecture.py "$(OUTPUT_FILE)" && cd ..
	@echo "$(GREEN)Architecture diagrams generated at assets/$(OUTPUT_FILE).png$(NC)"

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
	@markdownlint_bin="$$(command -v /opt/homebrew/bin/markdownlint || command -v /usr/local/bin/markdownlint || command -v markdownlint)"; \
		if [ -z "$$markdownlint_bin" ]; then \
			echo "$(RED)markdownlint is required but not installed. Install markdownlint-cli and re-run make check-markdown.$(NC)"; \
			exit 1; \
		fi; \
		"$$markdownlint_bin" "**/*.md" --ignore node_modules/
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
	@env -u GITHUB_TOKEN -u GH_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --offline --no-config . > /dev/null 2>&1 || \
		env -u GITHUB_TOKEN -u GH_TOKEN -u ZIZMOR_GITHUB_TOKEN zizmor --offline --no-config .

.PHONY: lint-editorconfig
lint-editorconfig: ## Check .editorconfig compliance
	# Note: Excluding gateway-api and monitoring helm charts due to auto-generated CRD files with long lines
	# Excluding unifi terragrunt.hcl due to long SSH public key that cannot be safely split
	@echo "$(GREEN)Checking .editorconfig compliance...$(NC)"
	@ec_bin="$$(command -v /opt/homebrew/bin/editorconfig-checker || command -v /usr/local/bin/editorconfig-checker || command -v editorconfig-checker || command -v ec)"; \
		if [ -z "$$ec_bin" ]; then \
			echo "$(RED)editorconfig-checker is required but not installed. Install editorconfig-checker and re-run make lint-editorconfig.$(NC)"; \
			exit 1; \
		fi; \
		"$$ec_bin" -exclude "(helm-charts/(gateway-api|monitoring)/.*|infrastructure/local/lhr/unifi/terragrunt\\.hcl)" || { \
		echo "$(RED)EditorConfig violations found. Please fix manually or use your editor's .editorconfig support.$(NC)"; \
		exit 1; \
	}
	@echo "$(GREEN)EditorConfig compliance check passed!$(NC)"

.PHONY: validate-argocd-manifest
validate-argocd-manifest: ## Validate ArgoCD manifest rendering with jsonnet
	@echo "$(GREEN)Validating ArgoCD manifest rendering...$(NC)"
	@command -v jsonnet >/dev/null 2>&1 || { echo "$(RED)jsonnet is required but not installed.$(NC)"; exit 1; }
	@cd argocd && jsonnet --yaml-stream manifest.jsonnet \
		--ext-str AWS_ACCOUNT_ID=000000000000 \
		--ext-str CNPG_BACKUP_BUCKET=test-bucket \
		--ext-str CNPG_BACKUP_ENDPOINT=https://test.example.com \
		--ext-str LONGHORN_BACKUP_TARGET=s3://test-bucket@region/ \
		--ext-str HOME_ASSISTANT_VOLUME_FROM_BACKUP=s3://test-bucket@region/?backup=test\&volume=test \
		> /dev/null
	@echo "$(GREEN)ArgoCD manifest validation passed!$(NC)"

.PHONY: format-python
format-python: poetry-install ## Format Python code with black
	@echo "$(GREEN)Formatting Python code with black...$(NC)"
	@cd diagrams && poetry run black . && cd ..
	@echo "$(GREEN)Python code formatting complete!$(NC)"

.PHONY: test
test: validate-argocd-manifest check-yaml lint-editorconfig lint-terraform lint-terragrunt check-markdown lint-zizmor validate-helm-charts ## Run all validation and quality checks
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

.PHONY: unlock
unlock: ## Unlock a LUKS node through initramfs SSH (usage: make unlock raspberrypi-00)
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "$(RED)Usage: make unlock <node-name>$(NC)"; \
		exit 1; \
	fi
	@target="$(NODE_TARGET)"; \
	host="$$(TARGET="$$target" yq -r '$(LUKS_UNLOCK_HOST_QUERY)' $(ANSIBLE_INVENTORY))"; \
	echo "$(GREEN)Unlocking $$target ($$host):$(LUKS_UNLOCK_PORT)...$(NC)"; \
	direnv exec . ./hack/luks-cryptroot-unlock.sh "$$host" "$(LUKS_UNLOCK_PORT)" --env-passfifo
