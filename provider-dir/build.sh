#!/bin/bash
set -e

echo "🔨 Building provider..."
go build -o terraform-provider-mylocal

echo "✅ Provider built successfully at: $(pwd)/terraform-provider-mylocal"
