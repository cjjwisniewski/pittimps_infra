resource "azurerm_resource_group" "rg" {
  name     = "${local.project_prefix}com"
  location = local.region
  tags     = local.tags
}
