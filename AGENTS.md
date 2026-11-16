# pittimps_infra — Agent Guidelines & Repository Specifics

This repository contains the Terraform configuration for **`pittimps.com`** (`cjjwisniewski/pittimps_infra`).

## 1. Git, CI/CD & Documentation Continuity
- **Commit & Push**: Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat(scope):`, `fix(scope):`, `chore(scope):`, `docs(scope):`) and push to `origin/main`.
- **Keep BookStack up to date**: Whenever Azure resources, Cloudflare DNS/rules, or OIDC/CI rules change, update the **`Pitt Imps`** book in BookStack (`HomeLab` shelf, via `bookstack-mcp` at `http://127.0.0.1:8002/mcp`).

## 2. Terraform Workflow & Safety Guards
- **Remote State**: Backend is `azurerm` in resource group `pittimpscom`, storage account `pittimpscom`, container `tfstate`, key `terraform.tfstate`.
- **No Auto-Apply on Push**: `.github/workflows/deploy.yml` runs `terraform init`, `terraform validate`, and `terraform plan` only on `push` and `pull_request` to `main`.
- **Manual Apply via `workflow_dispatch`**: Trigger `workflow_dispatch` with `apply=true` (and optional `untaint_address`) to apply changes.
- **Destructive-Plan Guard**: CI inspects `terraform show -json tfplan` and **aborts if `DESTROY_COUNT > 0`** (any `delete` or replacement action) to protect stateful resources (`pittimpscom` storage account and `tfstate`).
- **Local Runs**: Require `CLOUDFLARE_API_TOKEN` in the environment (`export CLOUDFLARE_API_TOKEN="..."`) and Azure auth (`az login`).

## 3. Infrastructure Coupling & Invariants
- **Azure Custom Domain Validation**:
  - `azurerm_storage_account.static_site` (`pittimpscom`, `eastus2`, `StorageV2`, `Standard_LRS`) binds `pittimps.com` (`use_subdomain = true`) and depends on `cloudflare_record.asverify`.
  - `cloudflare_record.asverify` (`asverify` -> `asverify.pittimpscom.z20.web.core.windows.net`) **must remain `proxied = false`** so Azure can validate the domain.
- **Cloudflare Edge & Redirects**:
  - `@` and `www` CNAMEs point to `pittimpscom` `primary_web_host` (`proxied = true`).
  - `cloudflare_page_rule.www_to_root` redirects `www.pittimps.com/*` -> `https://pittimps.com/$1` (`301`).
  - Zone SSL is `full` with `always_use_https = "on"`, `automatic_https_rewrites = "on"`, `brotli = "on"`, `email_obfuscation = "off"`, and `rocket_loader = "off"`.
  - `cloudflare_ruleset.security_headers` sets CSP, HSTS, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, and `Permissions-Policy` on `pittimps.com`.
- **GitHub Actions OIDC (`github.tf`)**:
  - `pittimps-github-deploy` Azure AD App/SP has a federated identity credential scoped strictly to `repo:cjjwisniewski/pittimps.com:ref:refs/heads/main` with `Storage Blob Data Contributor` on `pittimpscom`.
  - Both `azuread_application` and `azuread_service_principal` use `lifecycle { ignore_changes = [owners] }` to prevent drift when Terraform runs under a CI Service Principal.
