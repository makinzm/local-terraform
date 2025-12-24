# ローカル Terraform Provider 開発プロジェクト

TerraformのカスタムProviderをローカル環境で開発するためのサンプルプロジェクトです。

**HTTP Registry Server**を使用して、実際のPrivate Registryと同じ仕組みで動作します。


## 🚀 クイックスタート

```bash
# Devbox環境に入る
devbox shell

# ビルド→CA証明書作成→サーバー起動→適用→確認を一度に実行
make dev
```

## 📋 コマンド一覧

```bash
# 開発サイクル（全自動）
make dev

# Registry Server
make build-registry   # サーバーのビルド
make start-registry   # サーバー起動 (http://localhost:5758)
make stop-registry    # サーバー停止

# Provider
make build-provider    # Providerのビルド
make install-provider  # Providerをレジストリに追加

# Terraform
make init-client       # Terraform初期化
make validate          # 設定の検証
make plan              # プラン確認
make apply             # 適用（確認あり）
make apply-auto        # 適用（自動承認）

# 確認
make show              # 状態表示
make check-state       # 状態とOutputs表示

# クリーンアップ
make destroy           # リソース削除（確認あり）
make destroy-auto      # リソース削除（自動承認）
make clean             # 生成ファイル削除 + サーバー停止

# ヘルプ
make help
```

## 🏗️ プロジェクト構造

```
local-terraform/
├── provider-dir/           # Provider開発（Go）
├── registry-server/        # HTTP Registry Server
│   ├── main.go            # サーバー実装
│   └── providers/         # Providerバイナリ置き場（自動生成）
├── client-dir/             # Terraform実行
│   ├── main.tf            # Terraform設定
│   └── .terraformrc       # Registry設定
├── Makefile                # 開発タスク
└── devbox.json             # 環境設定
```

## 🌐 Registry Server について

このプロジェクトは**Terraform Registry Protocol**を実装したHTTPサーバーを使用します。

### 提供するエンドポイント

- `GET /.well-known/terraform.json` - Service Discovery
- `GET /v1/providers/{namespace}/{type}/versions` - Provider versions
- `GET /v1/providers/{namespace}/{type}/{version}/download/{os}/{arch}` - Download metadata
- `GET /providers/{os}_{arch}/terraform-provider-{type}_v{version}` - Binary download

### 特徴

- 🔄 実際のPrivate Registryと同じHTTP通信
- 📦 将来的なPrivate Registry移行が容易
- 🔍 リクエスト/レスポンスをログで確認可能

## 📚 参考リンク

- [Terraform | HashiCorp Developer](https://developer.hashicorp.com/terraform)
- [Terraform Registry Protocol](https://developer.hashicorp.com/terraform/internals/provider-registry-protocol)
- [Plugin Development](https://developer.hashicorp.com/terraform/plugin)
- [Devbox Documentation](https://www.jetpack.io/devbox/docs/)
