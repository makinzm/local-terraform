.PHONY: build-provider setup-registry install-provider init-client plan apply apply-auto destroy clean dev show validate check-state help

# デフォルトターゲット
.DEFAULT_GOAL := help

# Providerのビルド
build-provider:
	@echo "🔨 Building provider..."
	cd provider-dir && go mod tidy
	cd provider-dir && go build -o terraform-provider-mylocal
	@echo "✅ Provider built successfully"

# ローカルレジストリの作成
setup-registry:
	@echo "📦 Setting up local registry..."
	@mkdir -p .terraform-plugins/local.dev/makinzm/mylocal/1.0.0/$$(go env GOOS)_$$(go env GOARCH)
	@echo "✅ Registry created"

# Providerをレジストリに追加
install-provider: build-provider setup-registry
	@echo "📥 Installing provider to local registry..."
	@cp provider-dir/terraform-provider-mylocal .terraform-plugins/local.dev/makinzm/mylocal/1.0.0/$$(go env GOOS)_$$(go env GOARCH)/terraform-provider-mylocal_v1.0.0
	@echo "✅ Provider installed to registry"

# クライアントの初期化
init-client: install-provider
	@echo "🎬 Initializing Terraform client..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform init
	@echo "✅ Terraform initialized"

# Terraform validate
validate: install-provider
	@echo "🔍 Validating Terraform configuration..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform validate
	@echo "✅ Configuration is valid"

# Plan実行
plan: install-provider
	@echo "📋 Running terraform plan..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform plan

# Apply実行
apply: install-provider
	@echo "🚀 Running terraform apply..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform apply

# Apply（自動承認）
apply-auto: install-provider
	@echo "🚀 Running terraform apply (auto-approve)..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform apply -auto-approve

# 状態の表示
show:
	@echo "📊 Showing current state..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform show

# 状態の確認（詳細）
check-state:
	@echo "📊 Checking Terraform state..."
	@if [ -f client-dir/terraform.tfstate ]; then \
		echo "✅ State file exists"; \
		(cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform state list); \
		echo ""; \
		echo "📝 Outputs:"; \
		(cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform output); \
	else \
		echo "❌ No state file found. Run 'make apply' first."; \
	fi

# Destroy
destroy:
	@echo "🗑️  Destroying resources..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform destroy

# Destroy（自動承認）
destroy-auto:
	@echo "🗑️  Destroying resources (auto-approve)..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform destroy -auto-approve

# クリーンアップ
clean:
	@echo "🧹 Cleaning up..."
	cd provider-dir && rm -f terraform-provider-mylocal
	cd client-dir && rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
	rm -rf .terraform-plugins
	@echo "✅ Cleanup complete"

# 開発サイクル（ビルド→レジストリ追加→初期化→Apply→確認）
dev: install-provider
	@echo "🎬 Initializing Terraform..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform init -upgrade
	@echo "🔄 Running development cycle..."
	cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform apply -auto-approve
	@echo ""
	@echo "📊 Current state:"
	@$(MAKE) --no-print-directory check-state

# ヘルプ
help:
	@echo "📚 Available targets:"
	@echo "  make build-provider  - Build the Terraform provider"
	@echo "  make setup-registry  - Create local registry structure"
	@echo "  make install-provider - Install provider to local registry"
	@echo "  make init-client     - Initialize Terraform client"
	@echo "  make validate        - Validate Terraform configuration"
	@echo "  make plan            - Run terraform plan"
	@echo "  make apply           - Run terraform apply (with confirmation)"
	@echo "  make apply-auto      - Run terraform apply (auto-approve)"
	@echo "  make show            - Show current terraform state"
	@echo "  make check-state     - Check state and show outputs"
	@echo "  make destroy         - Destroy all resources (with confirmation)"
	@echo "  make destroy-auto    - Destroy all resources (auto-approve)"
	@echo "  make clean           - Clean up generated files and registry"
	@echo "  make dev             - Development cycle (build + install + apply + check)"
	@echo "  make help            - Show this help message"
