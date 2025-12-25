# 認証・認可の仕組み

このローカルTerraform環境では、2つの**独立した**認証メカニズムが実装されています。

## 🔐 認証の全体像

```
┌─────────────┐     ①Registry認証      ┌──────────────┐
│  Terraform  ├──────────────────────►│   Registry   │
│    CLI      │   (providerバイナリ取得)  │   Server     │
└──────┬──────┘                        └──────────────┘
       │                                     
       │ ②Provider認証                        
       │ (実際のリソース操作)                
       ▼                                     
  ┌─────────┐                                
  │Provider │──────►  リソース操作（ファイル作成等）       
  └─────────┘                                
```

**重要**: ①と②は完全に別物で、それぞれ独立して設定・管理されます。

---

## 1. Registry認証（Providerバイナリのダウンロード）

### 目的
Terraform Registryからproviderバイナリをダウンロードする際の認証。

### 認証方法
`.terraformrc` ファイルで設定したトークンがHTTPヘッダー（Bearer認証）として送信されます。

### 設定ファイル

**client-dir/.terraformrc:**
```hcl
credentials "localhost:5758" {
  token = "my-local-dev-token"
}
```

または、ホームディレクトリに配置：
```bash
cat > ~/.terraformrc << 'EOF'
credentials "localhost:5758" {
  token = "my-local-dev-token"
}
EOF
```

### 環境変数での設定

Registry Server側で認証トークンを変更可能：
```bash
export REGISTRY_TOKEN="your-custom-token"
```

### 保護されているエンドポイント

- `GET /v1/providers/{namespace}/{type}/versions` - バージョン一覧の取得
- `GET /v1/providers/{namespace}/{type}/{version}/download/{os}/{arch}` - ダウンロードメタデータ

### 保護されていないエンドポイント

- `GET /.well-known/terraform.json` - サービスディスカバリー
- `GET /providers/*` - バイナリファイル本体（SHA256署名で検証）
- SHA256SUMS関連エンドポイント（検証用公開情報）

### 動作確認

```bash
# 認証なし（失敗するはず）
curl -k https://localhost:5758/v1/providers/makinzm/mylocal/versions

# 正しい認証（成功）
curl -k -H "Authorization: Bearer my-local-dev-token" \
  https://localhost:5758/v1/providers/makinzm/mylocal/versions
```

---

## 2. Provider認証（リソース操作）

### 目的
Providerが実際のリソース（ファイル作成等）を操作する際の認証。

**この認証情報はRegistry Serverには送信されません。**

### 設定方法

**client-dir/main.tf:**
```hcl
provider "mylocal" {
  api_key = "my-service-api-key"
}
```

### 環境変数での設定

```bash
export MYLOCAL_API_KEY="my-service-api-key"
```

```hcl
provider "mylocal" {
  # api_key は環境変数から自動取得される
}
```

### 動作

- `terraform apply` 実行時、Providerが `api_key` を受け取る
- リソース操作（Create/Read/Update/Delete）時に、この認証情報を使用
- 今回の実装では、API keyが設定されている場合にログに表示される

---

## 📋 実行フローの詳細

### `terraform init` の流れ

1. Terraform CLIが `.terraformrc` から認証トークンを読み込む
2. Registry Serverに接続（Bearer認証）
   - `GET /.well-known/terraform.json` → 認証不要
   - `GET /v1/providers/.../versions` → **Registry認証が必要**
   - `GET /v1/providers/.../download/...` → **Registry認証が必要**
3. バイナリダウンロード
   - `GET /providers/.../*.zip` → 認証不要（SHA256で検証）
4. SHA256SUMS検証
   - 署名ファイルとGPG公開鍵で完全性を確認

### `terraform apply` の流れ

1. Providerバイナリを実行
2. Provider設定（`provider "mylocal"`）から `api_key` を読み込む
3. リソース操作時に **Provider認証** を使用
   - この段階ではRegistry Serverとは通信しない

---

## 🔧 開発環境での使用方法

### 1. 設定ファイルの準備

```bash
# Registry認証の設定
cat > client-dir/.terraformrc << 'EOF'
credentials "localhost:5758" {
  token = "my-local-dev-token"
}
EOF

# main.tf は既に設定済み（api_key = "my-service-api-key"）
```

### 2. Registry Serverの起動

```bash
make dev
```

サーバー起動時のログで認証トークンを確認：
```
🔑 Registry authentication enabled - Token: my-local-dev-token
```

### 3. Terraform実行

```bash
cd client-dir

# Registry認証を使ってproviderをダウンロード
terraform init

# Provider認証を使ってリソースを操作
terraform apply
```

### 4. ログでの確認

**Registry Server側:**
```
✅ Authenticated request from 127.0.0.1 to /v1/providers/makinzm/mylocal/versions
```

**Provider側（terraform apply実行時）:**
```
✅ [Authenticated with API key] Creating file: example.txt with content: Hello from monorepo!
```

---

## 🔒 セキュリティのベストプラクティス

### 開発環境
- デフォルトトークンをそのまま使用してOK
- ログにトークンが表示されるのは学習目的のため

### 本番環境
1. **環境変数を使用**
   ```bash
   export REGISTRY_TOKEN="strong-random-token-here"
   export MYLOCAL_API_KEY="another-strong-token"
   ```

2. **トークンをファイルに含めない**
   ```bash
   # .gitignore に追加
   echo ".terraformrc" >> .gitignore
   echo "*.tfvars" >> .gitignore
   ```

3. **トークンのログ出力を無効化**
   - `main.go` からトークン表示部分を削除

4. **定期的なトークンローテーション**

---

## 🧪 認証のテスト

### Registry認証のテスト

```bash
# 成功するケース
curl -k -H "Authorization: Bearer my-local-dev-token" \
  https://localhost:5758/v1/providers/makinzm/mylocal/versions

# 失敗するケース（401 Unauthorized）
curl -k https://localhost:5758/v1/providers/makinzm/mylocal/versions
curl -k -H "Authorization: Bearer wrong-token" \
  https://localhost:5758/v1/providers/makinzm/mylocal/versions
```

### Provider認証のテスト

```bash
# API keyなしでapply
terraform apply  # → 認証なしのログが表示される

# API keyありでapply（main.tfで設定済み）
terraform apply  # → [Authenticated with API key] のログが表示される

# 環境変数で設定
export MYLOCAL_API_KEY="my-service-api-key"
terraform apply
```

---

## ❓ トラブルシューティング

### "Unauthorized: Bearer token required" エラー

**原因**: `.terraformrc` が読み込まれていない

**解決方法**:
```bash
# client-dir/.terraformrc を確認
cat client-dir/.terraformrc

# または TF_CLI_CONFIG_FILE を明示的に指定
export TF_CLI_CONFIG_FILE=$(pwd)/client-dir/.terraformrc
terraform init
```

### "Unauthorized: invalid token" エラー

**原因**: トークンが一致していない

**解決方法**:
```bash
# Registry Serverのログでトークンを確認
# 🔑 Registry authentication enabled - Token: my-local-dev-token

# .terraformrc のトークンと一致させる
```

### Provider設定が認識されない

**原因**: `terraform init` が必要

**解決方法**:
```bash
terraform init -upgrade
```

---

## 📚 参考リンク

- [Terraform Registry Protocol](https://developer.hashicorp.com/terraform/internals/provider-registry-protocol)
- [Terraform CLI Configuration](https://developer.hashicorp.com/terraform/cli/config/config-file)
- [Provider Development](https://developer.hashicorp.com/terraform/plugin/sdkv2)
