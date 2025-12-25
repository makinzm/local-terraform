package main

import (
	"context"
	"fmt"
	"time"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourceFile() *schema.Resource {
	return &schema.Resource{
		CreateContext: resourceFileCreate,
		ReadContext:   resourceFileRead,
		UpdateContext: resourceFileUpdate,
		DeleteContext: resourceFileDelete,

		Schema: map[string]*schema.Schema{
			"content": {
				Type:     schema.TypeString,
				Required: true,
			},
			"name": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"created_at": {
				Type:     schema.TypeString,
				Computed: true,
			},
		},
	}
}

func resourceFileCreate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	// Provider設定を取得
	config, ok := m.(*ProviderConfig)
	if ok && config.APIKey != "" {
		fmt.Printf("✅ [Authenticated with API key] Creating file: %s with content: %s\n",
			d.Get("name").(string), d.Get("content").(string))
	} else {
		fmt.Printf("✅ Creating file: %s with content: %s\n",
			d.Get("name").(string), d.Get("content").(string))
	}

	name := d.Get("name").(string)
	d.SetId(name)
	d.Set("created_at", time.Now().Format(time.RFC3339))

	return nil
}

func resourceFileRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	config, ok := m.(*ProviderConfig)
	if ok && config.APIKey != "" {
		fmt.Printf("📖 [Authenticated] Reading file: %s\n", d.Id())
	} else {
		fmt.Printf("📖 Reading file: %s\n", d.Id())
	}
	return nil
}

func resourceFileUpdate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	content := d.Get("content").(string)
	config, ok := m.(*ProviderConfig)
	if ok && config.APIKey != "" {
		fmt.Printf("🔄 [Authenticated] Updating file: %s with new content: %s\n", d.Id(), content)
	} else {
		fmt.Printf("🔄 Updating file: %s with new content: %s\n", d.Id(), content)
	}
	return nil
}

func resourceFileDelete(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	config, ok := m.(*ProviderConfig)
	if ok && config.APIKey != "" {
		fmt.Printf("🗑️  [Authenticated] Deleting file: %s\n", d.Id())
	} else {
		fmt.Printf("🗑️  Deleting file: %s\n", d.Id())
	}
	return nil
}
