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

    security_header {
      enabled            = true
      max_age            = 31536000
      include_subdomains = true
      nosniff            = true
    }
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
        value     = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'"
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

# Redirect www to root domain (modern Redirect Ruleset replacing deprecated Page Rule)
resource "cloudflare_ruleset" "www_to_root" {
  zone_id     = data.cloudflare_zone.pittimps.id
  name        = "pittimps.com WWW to Root Redirect"
  description = "301 redirect www.pittimps.com to https://pittimps.com preserving path and query"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules {
    action      = "redirect"
    expression  = "(http.host eq \"www.${local.domain_name}\")"
    description = "Redirect www to root"
    enabled     = true

    action_parameters {
      from_value {
        status_code           = 301
        preserve_query_string = true

        target_url {
          expression = "concat(\"https://${local.domain_name}\", http.request.uri.path)"
        }
      }
    }
  }
}

# Edge Cache Rules for static HTML & assets on pittimps.com
resource "cloudflare_ruleset" "cache_rules" {
  zone_id     = data.cloudflare_zone.pittimps.id
  name        = "pittimps.com Static Site Cache Rules"
  description = "Cache static HTML and assets at Cloudflare edge respecting origin Cache-Control"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action      = "set_cache_settings"
    expression  = "(http.host eq \"${local.domain_name}\")"
    description = "Cache static HTML and assets respecting origin Cache-Control"
    enabled     = true

    action_parameters {
      cache = true

      edge_ttl {
        mode = "respect_origin"
      }

      browser_ttl {
        mode = "respect_origin"
      }
    }
  }
}

# DNS CAA records restricting certificate issuance to Cloudflare Universal SSL CAs
locals {
  caa_records = {
    letsencrypt_issue     = { tag = "issue", value = "letsencrypt.org" }
    letsencrypt_issuewild = { tag = "issuewild", value = "letsencrypt.org" }
    google_issue          = { tag = "issue", value = "pki.goog" }
    google_issuewild      = { tag = "issuewild", value = "pki.goog" }
    digicert_issue        = { tag = "issue", value = "digicert.com" }
    digicert_issuewild    = { tag = "issuewild", value = "digicert.com" }
    iodef                 = { tag = "iodef", value = "mailto:cameron@undo.is" }
  }
}

resource "cloudflare_record" "caa" {
  for_each = local.caa_records

  zone_id = data.cloudflare_zone.pittimps.id
  name    = "@"
  type    = "CAA"

  data {
    flags = "0"
    tag   = each.value.tag
    value = each.value.value
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

# Email anti-spoofing records (non-sending domain: null SPF, null DKIM, strict DMARC reject)
resource "cloudflare_record" "spf" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "@"
  type    = "TXT"
  content = "v=spf1 -all"
}

resource "cloudflare_record" "dkim_null" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "*._domainkey"
  type    = "TXT"
  content = "v=DKIM1; p="
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.pittimps.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
}
