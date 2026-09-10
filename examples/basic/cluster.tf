data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "example-cluster"
  dns_prefix          = "example-cluster"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  node_provisioning_profile {
    default_node_pools = "Auto"
  }

  default_node_pool {
    name           = "default"
    vm_size        = "Standard_D2s_v7"
    node_count     = 1
    vnet_subnet_id = azurerm_subnet.this.id

    upgrade_settings {
      node_soak_duration_in_minutes = 0
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "admin" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.this.id
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "user" {
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  scope                = azurerm_kubernetes_cluster.this.id
  principal_id         = data.azurerm_client_config.current.object_id
}
