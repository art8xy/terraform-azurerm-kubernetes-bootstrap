resource "azurerm_resource_group" "this" {
  name     = "example-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "this" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                            = "example-subnet"
  address_prefixes                = ["10.0.0.0/24"]
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  default_outbound_access_enabled = true
}
