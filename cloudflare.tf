data "cloudflare_zone" "pittimps" {
  name = local.domain_name
}

resource "cloudflare_record" "root_cname" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "@"
  content = azurerm_storage_account.static_site.primary_web_host
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "www_cname" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "www"
  content = azurerm_storage_account.static_site.primary_web_host
  type    = "CNAME"
  proxied = true
}

# Best Practices Zone Settings
resource "cloudflare_zone_settings_override" "pittimps_settings" {
  zone_id = data.cloudflare_zone.pittimps.id

  settings {
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    brotli                   = "on"
    security_level           = "medium"
    ssl                      = "full"
  }
}

# Redirect www to root domain
resource "cloudflare_page_rule" "www_to_root" {
  zone_id = data.cloudflare_zone.pittimps.id
  target  = "www.${local.domain_name}/*"
  status  = "active"

  actions {
    forwarding_url {
      url         = "https://${local.domain_name}/$1"
      status_code = 301
    }
  }
}
# asverify record to allow Azure to natively validate the custom domain for the Storage Account
resource "cloudflare_record" "asverify" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "asverify"
  content = "asverify.pittimpscom.z20.web.core.windows.net"
  type    = "CNAME"
  proxied = false
}
