resource "azurerm_storage_account" "static_site" {
  name                     = "${local.project_prefix}com"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # static_website is supported in BlobStorage or StorageV2
  account_kind = "StorageV2"

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  tags = local.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.static_site.name
  container_access_type = "private"
}
