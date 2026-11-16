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
    email_obfuscation        = "off"
    rocket_loader            = "off"
    security_level           = "medium"
    ssl                      = "full"
  }
}

# Edge Security Headers for pittimps.com
resource "cloudflare_ruleset" "security_headers" {
  zone_id     = data.cloudflare_zone.pittimps.id
  name        = "pittimps.com Security Headers"
  description = "Add CSP, HSTS, and security response headers for pittimps.com"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules {
    action      = "rewrite"
    expression  = "(http.host eq \"${local.domain_name}\")"
    description = "Set security headers on pittimps.com"
    enabled     = true

    action_parameters {
      headers {
        name      = "Content-Security-Policy"
        operation = "set"
        value     = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'"
      }
      headers {
        name      = "Permissions-Policy"
        operation = "set"
        value     = "camera=(), microphone=(), geolocation=()"
      }
      headers {
        name      = "Referrer-Policy"
        operation = "set"
        value     = "strict-origin-when-cross-origin"
      }
      headers {
        name      = "Strict-Transport-Security"
        operation = "set"
        value     = "max-age=31536000; includeSubDomains"
      }
      headers {
        name      = "X-Content-Type-Options"
        operation = "set"
        value     = "nosniff"
      }
      headers {
        name      = "X-Frame-Options"
        operation = "set"
        value     = "DENY"
      }
    }
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
