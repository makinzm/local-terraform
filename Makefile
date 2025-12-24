.PHONY: build-provider init-client plan apply apply-auto destroy clean dev show validate check-state help

# デフォルトターゲット
.DEFAULT_GOAL := help

# Devbox環境でコマンドを実行
DEVBOX := devbox run --

# Providerのビルド
build-provider:
	@echo "🔨 Building provider..."
	cd provider-dir && $(DEVBOX) go mod download
	cd provider-dir && $(DEVBOX) go build -o terraform-provider-mylocal
	@echo "✅ Provider built successfully"

# クライアントの初期化
init-client: build-provider
	@echo "🎬 Initializing Terraform client..."
	cd client-dir && $(DEVBOX) terraform init
	@echo "✅ Terraform initialized"

# Terraform validate
validate: build-provider
	@echo "🔍 Validating Terraform configuration..."
	cd client-dir && $(DEVBOX) terraform validate
	@echo "✅ Configuration is valid"

# Plan実行
plan: build-provider
	@echo "📋 Running terraform plan..."
	cd client-dir && $(DEVBOX) terraform plan

# Apply実行
apply: build-provider
	@echo "🚀 Running terraform apply..."
	cd client-dir && $(DEVBOX) terraform apply

# Apply（自動承認）
apply-auto: build-provider
	@echo "🚀 Running terraform apply (auto-approve)..."
	cd client-dir && $(DEVBOX) terraform apply -auto-approve

# 状態の表示
show:
	@echo "📊 Showing current state..."
	cd client-dir && $(DEVBOX) terraform show

# 状態の確認（詳細）
check-state:
	@echo "📊 Checking Terraform state..."
	@if [ -f client-dir/terraform.tfstate ]; then \
		echo "✅ State file exists"; \
		cd client-dir && $(DEVBOX) terraform state list; \
		echo ""; \
		echo "📝 Outputs:"; \
		cd client-dir && $(DEVBOX) terraform output; \
	else \
		echo "❌ No state file found. Run 'make apply' first."; \
	fi

# Destroy
destroy:
	@echo "🗑️  Destroying resources..."
	cd client-dir && $(DEVBOX) terraform destroy

# Destroy（自動承認）
destroy-auto:
	@echo "🗑️  Destroying resources (auto-approve)..."
	cd client-dir && $(DEVBOX) terraform destroy -auto-approve

# クリーンアップ
clean:
	@echo "🧹 Cleaning up..."
	cd provider-dir && rm -f terraform-provider-mylocal
	cd client-dir && rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
	@echo "✅ Cleanup complete"

# 開発サイクル（ビルド→Apply→確認）
dev: build-provider
	@echo "🔄 Running development cycle..."
	cd client-dir && $(DEVBOX) terraform apply -auto-approve
	@echo ""
	@echo "📊 Current state:"
	@$(MAKE) --no-print-directory check-state

# ヘルプ
help:
	@echo "📚 Available targets:"
	@echo "  make build-provider  - Build the Terraform provider"
	@echo "  make init-client     - Initialize Terraform client"
	@echo "  make validate        - Validate Terraform configuration"
	@echo "  make plan            - Run terraform plan"
	@echo "  make apply           - Run terraform apply (with confirmation)"
	@echo "  make apply-auto      - Run terraform apply (auto-approve)"
	@echo "  make show            - Show current terraform state"
	@echo "  make check-state     - Check state and show outputs"
	@echo "  make destroy         - Destroy all resources (with confirmation)"
	@echo "  make destroy-auto    - Destroy all resources (auto-approve)"
	@echo "  make clean           - Clean up generated files"
	@echo "  make dev             - Development cycle (build + apply + check)"
	@echo "  make help            - Show this help message"
