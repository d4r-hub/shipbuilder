.PHONY: help init build-open build-closed test clean validate vault-auth build-baseline

help: ## Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk '/^[a-zA-Z_-]+:.*?##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize the development environment
	@echo "Installing required tools..."
	@command -v packer >/dev/null 2>&1 || (curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - && \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
		sudo apt-get update && sudo apt-get install -y packer)
	@command -v ansible >/dev/null 2>&1 || sudo apt-get install -y ansible
	@command -v gitlab-runner >/dev/null 2>&1 || (curl -L "https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb" -o gitlab-runner.deb && \
		sudo dpkg -i gitlab-runner.deb && rm gitlab-runner.deb)
	@if [ ! -f .env ]; then cp .env.example .env; fi

build-open: ## Build image for open environment
	@echo "Building open environment image..."
	packer build -var-file=packer/variables.open.pkrvars.hcl packer/main.pkr.hcl

build-closed: ## Build image for closed environment
	@echo "Building closed environment image..."
	packer build -var-file=packer/variables.closed.pkrvars.hcl packer/main.pkr.hcl

test: ## Run tests
	@echo "Running tests..."
	ansible-playbook -i localhost, ansible/customize.yml --check
	packer validate packer/main.pkr.hcl
	packer validate -var-file=packer/variables.open.pkrvars.hcl packer/main.pkr.hcl
	packer validate -var-file=packer/variables.closed.pkrvars.hcl packer/main.pkr.hcl

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf output-* packer_cache/ *.log *.manifest *.json
	rm -f *.qcow2 *.ova *.vmdk *.vhd *.img

validate: ## Validate configurations
	@echo "Validating configurations..."
	packer validate packer/main.pkr.hcl
	packer validate -var-file=packer/variables.open.pkrvars.hcl packer/main.pkr.hcl
	packer validate -var-file=packer/variables.closed.pkrvars.hcl packer/main.pkr.hcl
	ansible-playbook -i localhost, ansible/customize.yml --syntax-check

lint: ## Run linters
	@echo "Running linters..."
	ansible-lint ansible/customize.yml
	packer fmt -check packer/
	shellcheck scripts/*.sh

ci: ## Run CI pipeline locally
	@echo "Running CI pipeline..."
	gitlab-ci-multi-runner exec docker build_baseline
	gitlab-ci-multi-runner exec docker customize_open
	gitlab-ci-multi-runner exec docker customize_closed

vault-auth: ## Authenticate with Vault and get Artifactory credentials
	@echo "Authenticating with Vault..."
	@if [ -z "$(VAULT_USERNAME)" ] || [ -z "$(VAULT_PASSWORD)" ]; then \
		echo "Error: VAULT_USERNAME and VAULT_PASSWORD must be set"; \
		exit 1; \
	fi
	@bash scripts/vault-auth.sh -u "$(VAULT_USERNAME)" -p "$(VAULT_PASSWORD)" \
		$(if $(VAULT_ADDR),-a "$(VAULT_ADDR)") \
		$(if $(TOKEN_FILE),-t "$(TOKEN_FILE)")

build-baseline: ## Build baseline images using Image Builder
	@echo "Building baseline images..."
	@if [ -z "$(COMPOSER_TOKEN)" ]; then \
		echo "Error: COMPOSER_TOKEN must be set"; \
		exit 1; \
	fi
	@bash scripts/build_baseline.sh \
		$(if $(COMPOSER_URL),-u "$(COMPOSER_URL)") \
		$(if $(BLUEPRINT_FILE),-b "$(BLUEPRINT_FILE)") \
		$(if $(OUTPUT_DIR),-o "$(OUTPUT_DIR)") \
		$(if $(DEBUG),-d) 