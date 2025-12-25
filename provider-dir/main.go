package main

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/v2/plugin"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		ProviderFunc: Provider,
	})
}

func Provider() *schema.Provider {
	return &schema.Provider{
		Schema: map[string]*schema.Schema{
			"api_key": {
				Type:        schema.TypeString,
				Optional:    true,
				DefaultFunc: schema.EnvDefaultFunc("MYLOCAL_API_KEY", ""),
				Description: "API key for mylocal service authentication",
				Sensitive:   true,
			},
		},
		ResourcesMap: map[string]*schema.Resource{
			"mylocal_file": resourceFile(),
		},
		DataSourcesMap:       map[string]*schema.Resource{},
		ConfigureContextFunc: providerConfigure,
	}
}

// ProviderConfig holds the provider configuration
type ProviderConfig struct {
	APIKey string
}

func providerConfigure(ctx context.Context, d *schema.ResourceData) (interface{}, diag.Diagnostics) {
	var diags diag.Diagnostics

	config := &ProviderConfig{
		APIKey: d.Get("api_key").(string),
	}

	// API keyの検証
	if config.APIKey == "" {
		diags = append(diags, diag.Diagnostic{
			Severity: diag.Error,
			Summary:  "Missing API Key",
			Detail:   "API key must be set via 'api_key' provider configuration or MYLOCAL_API_KEY environment variable",
		})
		return nil, diags
	}

	// 正しいAPI keyかどうかを検証
	if config.APIKey != "my-service-api-key" {
		diags = append(diags, diag.Diagnostic{
			Severity: diag.Error,
			Summary:  "Invalid API Key",
			Detail:   fmt.Sprintf("Invalid API key: '%s'.", config.APIKey),
		})
		return nil, diags
	}

	fmt.Printf("✅ Provider configured with valid API key\n")
	return config, diags
}
