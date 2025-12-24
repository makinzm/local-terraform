# ローカル Terraform Provider 開発プロジェクト

TerraformのカスタムProviderをローカル環境で開発するためのサンプルプロジェクトです。

## 🚀 クイックスタート

```bash
# Devbox環境に入る
devbox shell

# ビルド→適用→確認を一度に実行
make dev
```

## 📋 コマンド一覧

```bash
# 開発サイクル（ビルド→適用→確認）
make dev

# 個別実行
make build-provider   # Providerのビルド
make init-client      # Terraform初期化
make validate         # 設定の検証
make plan             # プラン確認
make apply            # 適用（確認あり）
make apply-auto       # 適用（自動承認）

# 確認
make show             # 状態表示
make check-state      # 状態とOutputs表示

# クリーンアップ
make destroy          # リソース削除（確認あり）
make destroy-auto     # リソース削除（自動承認）
make clean            # 生成ファイル削除

# ヘルプ
make help
```

## 🏗️ プロジェクト構造

```
local-terraform/
├── provider-dir/     # Provider開発（Go）
├── client-dir/       # Terraform実行
├── Makefile          # 開発タスク
├── devbox.json       # 環境設定
└── .terraformrc      # ローカルProvider設定
```

## 📚 参考リンク

- [Terraform | HashiCorp Developer](https://developer.hashicorp.com/terraform)
- [Plugin Development](https://developer.hashicorp.com/terraform/plugin)
- [Devbox Documentation](https://www.jetpack.io/devbox/docs/)
