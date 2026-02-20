# Azure Static Site Infrastructure

This repository contains Terraform code for provisioning the infrastructure required to host a static website (`pittimps.com`) on Azure Blob Storage, fronted by Cloudflare for CDN and HTTPS. It also sets up Azure AD Workload Identity Federation, allowing GitHub Actions to securely deploy updates to the Azure Storage Account without requiring long-lived secrets.

## Architecture

- **Azure Resource Group**: Logical container for all infrastructure components.
- **Azure Storage Account**: Uses the `static_website` feature to serve content from the automatically created `$web` container. State management is also handled via a private `tfstate` container.
- **Cloudflare DNS & Proxy**: Manages DNS records, redirects `www` to the root domain, enforces HTTPS (via Best Practices Zone Settings), and provides CDN capabilities natively.
- **Azure AD Identity**: An App Registration and Service Principal configured with federated credentials for GitHub Actions OIDC, allowing passwordless deployments.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.0.0)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for authenticating Terraform)
- An active Azure Subscription
- A Cloudflare account managing your domain's DNS

## Initialization & Usage

### 1. Authenticate with Azure
```bash
az login
```

### 2. Configure Cloudflare
Export your Cloudflare API token as an environment variable before running Terraform. This is required because the `cloudflare` provider reads this environment variable to authenticate.
```bash
export CLOUDFLARE_API_TOKEN="your_cloudflare_api_token_here"
```

### 3. Initialize & Apply
```bash
terraform init
terraform plan
terraform apply
```

## GitHub Actions Deployment

This project sets up secure, secretless deployments via GitHub Actions OIDC. After running `terraform apply`, Terraform outputs three important values needed for your GitHub Actions workflow:

- `azure_client_id`
- `azure_tenant_id`
- `azure_subscription_id`

You will need to add these as Repository Secrets (or Environment Variables) in your GitHub repository containing your site code. Configure your workflow to use the `azure/login` action with `client-id`, `tenant-id`, and `subscription-id`. 

> **Important**: Ensure you update the `github_repo` local variable in `locals.tf` to match your actual repository (e.g., `my-org/my-repo`) so the federated credential applies correctly to your GitHub Actions runs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
