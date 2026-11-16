# pittimps_infra — Azure & Cloudflare Infrastructure

Terraform configuration for provisioning the static website infrastructure for [`pittimps.com`](https://pittimps.com) on Azure Blob Storage (`$web`), fronted by Cloudflare DNS/CDN, with passwordless GitHub Actions OIDC deployment.

## Architecture

- **Azure Resource Group (`main.tf`)**: `pittimpscom` in `eastus2`.
- **Azure Storage Account (`storage.tf`)**: `pittimpscom` (`StorageV2`, `Standard_LRS`) with `static_website` (`index_document = "index.html"`, `error_404_document = "404.html"`) and custom domain `pittimps.com` (`use_subdomain = true`, `depends_on = [cloudflare_record.asverify]`).
- **Terraform Remote State (`providers.tf`, `storage.tf`)**: Stored in the private `tfstate` container (`terraform.tfstate`) on `pittimpscom`.
- **Cloudflare DNS & Proxy (`cloudflare.tf`)**:
  - `@` and `www` CNAMEs pointing to `pittimpscom`'s `primary_web_host` (`proxied = true`).
  - `asverify` CNAME -> `asverify.pittimpscom.z20.web.core.windows.net` (`proxied = false`) for Azure custom domain validation.
  - Page Rule redirecting `www.pittimps.com/*` -> `https://pittimps.com/$1` (`301`).
  - Zone settings override: `always_use_https = "on"`, `automatic_https_rewrites = "on"`, `brotli = "on"`, `security_level = "medium"`, `ssl = "full"`.
- **GitHub Actions OIDC (`github.tf`)**: Azure AD App & Service Principal `pittimps-github-deploy` with federated identity credential scoped to `repo:cjjwisniewski/pittimps.com:ref:refs/heads/main` and `Storage Blob Data Contributor` on `pittimpscom`.

## CI/CD Workflow (`.github/workflows/deploy.yml`)

- **Plan-only on Push/PR**: Pushes and pull requests to `main` run `terraform init`, `terraform validate`, and `terraform plan` only; auto-apply is disabled.
- **Manual Apply (`workflow_dispatch`)**: Trigger `workflow_dispatch` with `apply=true` (and optional `untaint_address`) to apply changes.
- **Destructive-Plan Guard**: The workflow inspects `terraform show -json tfplan` and aborts if any `delete` / replacement action is planned (`DESTROY_COUNT > 0`) to protect stateful resources.
- **Required GitHub Variables / Secrets**:
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (vars or secrets; OIDC for this infra repo)
  - `CLOUDFLARE_API_TOKEN` (secret)

## Local Usage

```bash
az login
export CLOUDFLARE_API_TOKEN="your_cloudflare_api_token_here"
terraform init
terraform plan
terraform apply
```

### Outputs

`terraform output` exposes `azure_client_id`, `azure_tenant_id`, and `azure_subscription_id` for `cjjwisniewski/pittimps.com` GitHub Actions deployment, plus `resource_group_name`, `storage_account_name`, `storage_primary_web_endpoint`, and `cloudflare_cname_target`.

## License

MIT License — see [LICENSE](LICENSE) for details.
