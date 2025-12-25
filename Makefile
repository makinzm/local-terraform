.PHONY: build-provider build-registry setup-certs setup-env start-registry stop-registry install-provider init-client plan apply apply-auto destroy clean clean-certs dev show validate check-state help

# デフォルトターゲット
.DEFAULT_GOAL := help

# .envファイルから環境変数を読み込むヘルパー
LOAD_ENV = set -a && [ -f client-dir/.env ] && . client-dir/.env && set +a

# 環境変数ファイルのセットアップ
setup-env:
	@if [ ! -f client-dir/.env ]; then \
		echo "📝 Creating .env file from .env.example..."; \
		cp client-dir/.env.example client-dir/.env; \
		echo "✅ .env file created. You can edit client-dir/.env if needed."; \
	fi

# 証明書のセットアップ
setup-certs:
	@echo "🔐 Setting up TLS certificates with mkcert..."
	@if ! command -v mkcert >/dev/null 2>&1; then \
		echo "❌ mkcert not found. Please install it first."; \
		echo "   Run: devbox shell"; \
		exit 1; \
	fi
	@echo "📋 Installing local CA (requires password)..."
	mkcert -install
	@echo "🔑 Generating certificates for localhost..."
	cd registry-server && mkcert localhost 127.0.0.1 ::1
	@echo "✅ Certificates created:"
	@echo "   - registry-server/localhost.pem"
	@echo "   - registry-server/localhost-key.pem"

# GPG鍵の生成
setup-gpg:
	@echo "🔐 Setting up GPG signing..."
	@mkdir -p registry-server/gpg-keys
	@if [ ! -f registry-server/gpg-keys/public-key.asc ] || [ ! -f registry-server/gpg-keys/key-id.txt ]; then \
		echo "🔑 Generating GPG key pair..."; \
		rm -rf registry-server/gpg-keys/*; \
		chmod 700 registry-server/gpg-keys && \
		echo "allow-loopback-pinentry" > registry-server/gpg-keys/gpg-agent.conf && \
		echo "%no-protection" > /tmp/gpg-gen-key.txt && \
		echo "Key-Type: RSA" >> /tmp/gpg-gen-key.txt && \
		echo "Key-Length: 4096" >> /tmp/gpg-gen-key.txt && \
		echo "Subkey-Type: RSA" >> /tmp/gpg-gen-key.txt && \
		echo "Subkey-Length: 4096" >> /tmp/gpg-gen-key.txt && \
		echo "Name-Real: Local Terraform Provider" >> /tmp/gpg-gen-key.txt && \
		echo "Name-Email: provider@localhost" >> /tmp/gpg-gen-key.txt && \
		echo "Expire-Date: 0" >> /tmp/gpg-gen-key.txt && \
		echo "%commit" >> /tmp/gpg-gen-key.txt && \
		gpg --homedir $$(pwd)/registry-server/gpg-keys --batch --pinentry-mode loopback --gen-key /tmp/gpg-gen-key.txt && \
		rm /tmp/gpg-gen-key.txt && \
		KEY_ID=$$(gpg --homedir $$(pwd)/registry-server/gpg-keys --list-keys --with-colons | grep '^pub' | cut -d':' -f5 | tail -n1) && \
		echo "Key ID: $$KEY_ID" && \
		gpg --homedir $$(pwd)/registry-server/gpg-keys --armor --export "$$KEY_ID" > registry-server/gpg-keys/public-key.asc && \
		echo "$$KEY_ID" > registry-server/gpg-keys/key-id.txt && \
		echo "✅ GPG key generated (ID: $$KEY_ID)"; \
	else \
		echo "✅ GPG keys already exist"; \
	fi

# SHA256SUMSファイルに署名
sign-shasums: setup-gpg
	@echo "✍️  Signing SHA256SUMS..."
	@cd registry-server && \
	platforms="linux_amd64"; \
	for platform in $$platforms; do \
		if [ -d "providers/$$platform" ]; then \
			cd "providers/$$platform" && \
			if [ -f "terraform-provider-mylocal_v1.0.0.zip" ]; then \
				echo "  📝 Creating SHA256SUMS for $$platform..."; \
				shasum -a 256 terraform-provider-mylocal_v1.0.0.zip > SHA256SUMS && \
				echo "  ✍️  Signing SHA256SUMS for $$platform..."; \
				if ! gpg --homedir $$(pwd)/../../gpg-keys --detach-sign SHA256SUMS; then \
					echo "❌ Failed to sign SHA256SUMS"; \
					exit 1; \
				fi; \
			fi; \
			cd ../..; \
		fi; \
	done
	@echo "✅ SHA256SUMS signed"

# Providerのビルド
build-provider:
	@echo "🔨 Building provider..."
	cd provider-dir && go mod tidy
	cd provider-dir && go build -o terraform-provider-mylocal
	@echo "✅ Provider built successfully"

# Registry Serverのビルド
build-registry: setup-certs
	@echo "🔨 Building registry server..."
	cd registry-server && go mod tidy
	cd registry-server && go build -o registry-server
	@echo "✅ Registry server built successfully"

# Registry Serverの起動
start-registry: build-registry install-provider setup-certs
	@echo "🚀 Starting registry server..."
	@cd registry-server && ./registry-server &
	@echo $$! > .registry-server.pid
	@sleep 2
	@echo "✅ Registry server started (PID: $$(cat .registry-server.pid))"
	@echo "📡 Access at: https://localhost:5758"
	@echo "🔐 CA certificate: registry-server/ca-cert.pem"

# Registry Serverの停止
stop-registry:
	@echo "🛑 Stopping registry server..."
	@if [ -f .registry-server.pid ]; then \
		PID=$$(cat .registry-server.pid); \
		if ps -p $$PID > /dev/null 2>&1; then \
			echo "   Stopping process (PID: $$PID)..."; \
			kill $$PID 2>/dev/null || true; \
			sleep 1; \
			if ps -p $$PID > /dev/null 2>&1; then \
				kill -9 $$PID 2>/dev/null || true; \
			fi; \
		fi; \
		rm -f .registry-server.pid; \
	fi
	@if lsof -ti:5758 >/dev/null 2>&1; then \
		echo "   Killing process on port 5758..."; \
		lsof -ti:5758 | xargs kill -9 2>/dev/null || true; \
		sleep 1; \
	fi
	@echo "✅ Registry server stopped"

# Providerをレジストリに追加
install-provider: build-provider setup-gpg
	@echo "📥 Installing provider to registry..."
	@mkdir -p registry-server/providers/$$(go env GOOS)_$$(go env GOARCH)
	@cp provider-dir/terraform-provider-mylocal registry-server/providers/$$(go env GOOS)_$$(go env GOARCH)/terraform-provider-mylocal_v1.0.0
	@echo "📦 Creating ZIP archive..."
	@cd registry-server/providers/$$(go env GOOS)_$$(go env GOARCH) && \
		zip -q terraform-provider-mylocal_v1.0.0.zip terraform-provider-mylocal_v1.0.0
	@$(MAKE) --no-print-directory sign-shasums
	@echo "✅ Provider installed and signed"

# クライアントの初期化
init-client: setup-env start-registry
	@echo "🎬 Initializing Terraform client..."
	@$(LOAD_ENV) && cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform init
	@echo "✅ Terraform initialized"

# Terraform validate
validate: setup-env start-registry
	@echo "🔍 Validating Terraform configuration..."
	@$(LOAD_ENV) && cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform validate
	@echo "✅ Configuration is valid"

# Plan実行
plan: setup-env start-registry
	@echo "📋 Running terraform plan..."
	@$(LOAD_ENV) && cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform plan

# Apply実行
apply: setup-env start-registry
	@echo "🚀 Running terraform apply..."
	@$(LOAD_ENV) && cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform apply

# Apply（自動承認）
apply-auto: setup-env start-registry
	@echo "🚀 Running terraform apply (auto-approve)..."
	@$(LOAD_ENV) && cd client-dir && TF_CLI_CONFIG_FILE=.terraformrc terraform apply -auto-approve

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
clean: stop-registry
	@echo "🧹 Cleaning up..."
	cd provider-dir && rm -f terraform-provider-mylocal
	cd registry-server && rm -f registry-server
	cd registry-server && rm -rf providers
	cd client-dir && rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
	rm -rf .terraform-plugins
	@echo "✅ Cleanup complete"
	@echo "ℹ️  Certificates are kept. Run 'make clean-certs' to remove them."
	@echo "ℹ️  .env file is kept for security. Remove manually if needed."

# 証明書も含めて完全クリーンアップ
clean-certs:
	@echo "🗑️  Removing certificates..."
	cd registry-server && rm -f localhost.pem localhost-key.pem
	@echo "✅ Certificates removed"

# 開発サイクル（ビルド→サーバー起動→初期化→Apply→確認）
dev: setup-env start-registry
	@echo "🎬 Initializing Terraform..."
	@$(LOAD_ENV) && cd client-dir && SSL_CERT_FILE=$$(mkcert -CAROOT)/rootCA.pem TF_CLI_CONFIG_FILE=.terraformrc terraform init -upgrade
	@echo "🔄 Running development cycle..."
	@$(LOAD_ENV) && cd client-dir && SSL_CERT_FILE=$$(mkcert -CAROOT)/rootCA.pem TF_CLI_CONFIG_FILE=.terraformrc terraform apply -auto-approve
	@echo ""
	@echo "📊 Current state:"
	@$(MAKE) --no-print-directory check-state

# ヘルプ
help:
	@echo "📚 Available commands:"
	@echo "  make build-provider   - Build the Terraform provider"
	@echo "  make build-registry   - Build the registry server"
	@echo "  make setup-env        - Create .env file from .env.example (auto-created when needed)"
	@echo "  make start-registry   - Start the registry server (https://localhost:5758)"
	@echo "  make install-provider - Install provider to registry"
	@echo "  make init-client      - Initialize Terraform client"
	@echo "  make validate         - Validate Terraform configuration"
	@echo "  make plan             - Run terraform plan"
	@echo "  make apply            - Run terraform apply (with confirmation)"
	@echo "  make apply-auto       - Run terraform apply (auto-approve)"
	@echo "  make show             - Show current terraform state"
	@echo "  make check-state      - Check state and show outputs"
	@echo "  make destroy          - Destroy all resources (with confirmation)"
	@echo "  make destroy-auto     - Destroy all resources (auto-approve)"
	@echo "  make clean            - Clean up generated files"
	@echo "  make dev              - Development cycle (start server + init + apply + check)"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "📝 Quick Start:"
	@echo "  Run 'make dev' to start development (.env will be auto-created)"
	@echo "  Edit client-dir/.env to customize your configuration"

