package main

import (
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	registryHost = "localhost:5758"
	namespace    = "makinzm"
	providerName = "mylocal"
	version      = "1.0.0"
)

func main() {
	// mkcertで生成した証明書を使用
	certFile := "localhost+2.pem"
	keyFile := "localhost+2-key.pem"

	// 証明書ファイルの存在確認
	if _, err := os.Stat(certFile); os.IsNotExist(err) {
		log.Fatalf("❌ Certificate file not found: %s (run 'make setup-certs' first)", certFile)
	}
	if _, err := os.Stat(keyFile); os.IsNotExist(err) {
		log.Fatalf("❌ Key file not found: %s (run 'make setup-certs' first)", keyFile)
	}

	tlsCert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		log.Fatalf("Failed to load mkcert certificates: %v", err)
	}

	http.HandleFunc("/.well-known/terraform.json", serviceDiscovery)
	http.HandleFunc(fmt.Sprintf("/v1/providers/%s/%s/versions", namespace, providerName), providerVersions)
	http.HandleFunc(fmt.Sprintf("/v1/providers/%s/%s/%s/download/", namespace, providerName, version), providerDownload)
	http.HandleFunc("/providers/", serveProviderBinary)
	http.HandleFunc(fmt.Sprintf("/v1/providers/%s/%s/%s/shasums", namespace, providerName, version), serveShasums)
	http.HandleFunc(fmt.Sprintf("/v1/providers/%s/%s/%s/shasums.sig", namespace, providerName, version), serveShaSumsSignature)
	http.HandleFunc(fmt.Sprintf("/v1/providers/%s/%s/%s/signing-keys", namespace, providerName, version), serveSigningKeys)

	server := &http.Server{
		Addr: registryHost,
		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{tlsCert},
			MinVersion:   tls.VersionTLS12,
		},
	}

	log.Printf("🚀 Terraform Registry Server starting on https://%s", registryHost)
	log.Printf("📦 Serving provider: %s/%s v%s", namespace, providerName, version)
	log.Printf("🔐 Using mkcert certificates: %s", certFile)
	log.Fatal(server.ListenAndServeTLS("", ""))
}

// generateCertificates is no longer used - we use mkcert certificates instead
// Keeping this function for reference only

// Service Discovery endpoint
func serviceDiscovery(w http.ResponseWriter, r *http.Request) {
	log.Printf("📡 Service Discovery: %s", r.URL.Path)
	response := map[string]interface{}{
		"providers.v1": fmt.Sprintf("https://%s/v1/providers/", registryHost),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Provider versions endpoint
func providerVersions(w http.ResponseWriter, r *http.Request) {
	log.Printf("📋 Provider Versions: %s", r.URL.Path)
	response := map[string]interface{}{
		"versions": []map[string]interface{}{
			{
				"version":   version,
				"protocols": []string{"5.0"},
				"platforms": []map[string]string{
					{
						"os":   runtime.GOOS,
						"arch": runtime.GOARCH,
					},
				},
			},
		},
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Provider download endpoint
func providerDownload(w http.ResponseWriter, r *http.Request) {
	osParam := r.URL.Query().Get("os")
	arch := r.URL.Query().Get("arch")

	if osParam == "" {
		osParam = runtime.GOOS
	}
	if arch == "" {
		arch = runtime.GOARCH
	}

	log.Printf("📥 Provider Download: %s/%s", osParam, arch)

	// プロバイダーバイナリのパス（ZIP形式）
	providerPath := filepath.Join("providers", fmt.Sprintf("%s_%s", osParam, arch),
		fmt.Sprintf("terraform-provider-%s_v%s.zip", providerName, version))

	// SHA256ハッシュを計算
	shasum, err := calculateSHA256(providerPath)
	if err != nil {
		log.Printf("❌ Failed to calculate SHA256: %v", err)
		http.Error(w, "Provider binary not found", http.StatusNotFound)
		return
	}

	log.Printf("🔐 SHA256: %s", shasum)

	downloadURL := fmt.Sprintf("https://%s/providers/%s_%s/terraform-provider-%s_v%s.zip",
		registryHost, osParam, arch, providerName, version)

	response := map[string]interface{}{
		"protocols":             []string{"5.0"},
		"os":                    osParam,
		"arch":                  arch,
		"filename":              fmt.Sprintf("terraform-provider-%s_v%s.zip", providerName, version),
		"download_url":          downloadURL,
		"shasums_url":           fmt.Sprintf("https://%s/v1/providers/%s/%s/%s/shasums?os=%s&arch=%s", registryHost, namespace, providerName, version, osParam, arch),
		"shasums_signature_url": fmt.Sprintf("https://%s/v1/providers/%s/%s/%s/shasums.sig?os=%s&arch=%s", registryHost, namespace, providerName, version, osParam, arch),
		"shasum":                shasum,
		"signing_keys":          getSigningKeys(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Serve provider binary
func serveProviderBinary(w http.ResponseWriter, r *http.Request) {
	log.Printf("📦 Serving Binary: %s", r.URL.Path)

	// Extract platform from path: /providers/{os}_{arch}/terraform-provider-mylocal_v1.0.0
	providerPath := filepath.Join("providers", filepath.Base(filepath.Dir(r.URL.Path)), filepath.Base(r.URL.Path))

	if _, err := os.Stat(providerPath); os.IsNotExist(err) {
		log.Printf("❌ Provider binary not found: %s", providerPath)
		http.Error(w, "Provider binary not found", http.StatusNotFound)
		return
	}

	log.Printf("✅ Serving: %s", providerPath)
	http.ServeFile(w, r, providerPath)
}

// calculateSHA256 calculates the SHA256 hash of a file
func calculateSHA256(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}

// Serve SHA256SUMS file
func serveShasums(w http.ResponseWriter, r *http.Request) {
	osParam := r.URL.Query().Get("os")
	arch := r.URL.Query().Get("arch")

	if osParam == "" {
		osParam = runtime.GOOS
	}
	if arch == "" {
		arch = runtime.GOARCH
	}

	log.Printf("📋 Serving SHA256SUMS for %s/%s", osParam, arch)

	shasumsPath := filepath.Join("providers", fmt.Sprintf("%s_%s", osParam, arch), "SHA256SUMS")

	if _, err := os.Stat(shasumsPath); os.IsNotExist(err) {
		log.Printf("❌ SHA256SUMS file not found: %s", shasumsPath)
		http.Error(w, "SHA256SUMS not found", http.StatusNotFound)
		return
	}

	log.Printf("✅ Serving SHA256SUMS: %s", shasumsPath)
	w.Header().Set("Content-Type", "text/plain")
	http.ServeFile(w, r, shasumsPath)
}

// Serve SHA256SUMS.sig file
func serveShaSumsSignature(w http.ResponseWriter, r *http.Request) {
	osParam := r.URL.Query().Get("os")
	arch := r.URL.Query().Get("arch")

	if osParam == "" {
		osParam = runtime.GOOS
	}
	if arch == "" {
		arch = runtime.GOARCH
	}

	log.Printf("🔏 Serving SHA256SUMS.sig for %s/%s", osParam, arch)

	sigPath := filepath.Join("providers", fmt.Sprintf("%s_%s", osParam, arch), "SHA256SUMS.sig")

	if _, err := os.Stat(sigPath); os.IsNotExist(err) {
		log.Printf("❌ Signature file not found: %s", sigPath)
		http.Error(w, "Signature not found", http.StatusNotFound)
		return
	}

	log.Printf("✅ Serving signature: %s", sigPath)
	w.Header().Set("Content-Type", "application/pgp-signature")
	http.ServeFile(w, r, sigPath)
}

// Serve signing keys
func serveSigningKeys(w http.ResponseWriter, r *http.Request) {
	log.Printf("🔑 Serving signing keys")

	response := map[string]interface{}{
		"gpg_public_keys": getSigningKeys()["gpg_public_keys"],
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// Get signing keys for response
func getSigningKeys() map[string]interface{} {
	publicKeyPath := "gpg-keys/public-key.asc"
	keyIDPath := "gpg-keys/key-id.txt"

	publicKey, err := os.ReadFile(publicKeyPath)
	if err != nil {
		log.Printf("⚠️  Warning: Could not read public key: %v", err)
		return map[string]interface{}{"gpg_public_keys": []interface{}{}}
	}

	keyID, err := os.ReadFile(keyIDPath)
	if err != nil {
		log.Printf("⚠️  Warning: Could not read key ID: %v", err)
		return map[string]interface{}{"gpg_public_keys": []interface{}{}}
	}

	// Remove newline from key ID
	keyIDStr := strings.TrimSpace(string(keyID))

	return map[string]interface{}{
		"gpg_public_keys": []map[string]interface{}{
			{
				"key_id":          keyIDStr,
				"ascii_armor":     string(publicKey),
				"trust_signature": "",
				"source":          "",
				"source_url":      nil,
			},
		},
	}
}
