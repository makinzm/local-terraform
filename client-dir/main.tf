terraform {
  required_providers {
    mylocal = {
      source  = "localhost:5758/makinzm/mylocal"
      version = "1.0.0"
    }
  }
}

provider "mylocal" {
  # Provider認証（実際のリソース操作用）
  # レジストリ認証とは別物で、Providerが管理するサービスへの認証情報
  # 環境変数 MYLOCAL_API_KEY で設定してください
  # api_key はここに記載せず、環境変数を使用することを推奨
}

resource "mylocal_file" "example" {
  name    = "example.txt"
  content = "Hello from monorepo!"
}

resource "mylocal_file" "another" {
  name    = "another.txt"
  content = "Another file"
}

output "file_id" {
  value       = mylocal_file.example.id
  description = "The ID of the example file"
}

output "created_at" {
  value       = mylocal_file.example.created_at
  description = "When the file was created"
}

output "all_files" {
  value = {
    example = {
      id         = mylocal_file.example.id
      name       = mylocal_file.example.name
      content    = mylocal_file.example.content
      created_at = mylocal_file.example.created_at
    }
    another = {
      id         = mylocal_file.another.id
      name       = mylocal_file.another.name
      content    = mylocal_file.another.content
      created_at = mylocal_file.another.created_at
    }
  }
  description = "All file resources"
}
