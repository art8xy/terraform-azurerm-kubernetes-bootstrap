locals {
  name        = "${var.cluster.name}-bootstrap"
  description = "${var.cluster.name} Bootstrap"

  force_trigger = var.force ? timestamp() : ""

  build_path = "${path.module}/.build"
  build_zip  = "${path.module}/bootstrap.zip"

  source_path = "${path.module}/source"
  source_hash = base64sha256(join("", concat([local.force_trigger], [
    for file in sort(fileset(local.source_path, "**/*")) : filesha256("${local.source_path}/${file}")
  ])))
}

action "local_command" "build" {
  config {
    working_directory = path.module

    command   = "sh"
    arguments = ["scripts/build.sh"]
  }
}

resource "terraform_data" "build" {
  triggers_replace = {
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
  }

  lifecycle {
    action_trigger {
      events     = [before_create]
      actions    = [action.local_command.build]
      on_failure = taint
    }
  }
}

resource "azurerm_subnet" "this" {
  name                 = local.name
  resource_group_name  = var.cluster.resource_group_name
  virtual_network_name = element(split("/", var.cluster.default_node_pool[0].vnet_subnet_id), 8)

  address_prefixes = [var.subnet]

  delegation {
    name = "vnet"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                = substr(replace(lower(local.name), "-", ""), 0, 24)
  location            = var.cluster.location
  resource_group_name = var.cluster.resource_group_name

  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "this" {
  name                  = local.name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "this" {
  name                = local.name
  location            = var.cluster.location
  resource_group_name = var.cluster.resource_group_name

  os_type  = "Linux"
  sku_name = "FC1"

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.name
  location            = var.cluster.location
  resource_group_name = var.cluster.resource_group_name

  retention_in_days = 30

  tags = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = local.name
  location            = var.cluster.location
  resource_group_name = var.cluster.resource_group_name

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.this.id

  tags = var.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = local.name
  location            = var.cluster.location
  resource_group_name = var.cluster.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id

  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.this.primary_access_key

  storage_container_type     = "blobContainer"
  storage_container_endpoint = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.this.name}"

  virtual_network_subnet_id = azurerm_subnet.this.id

  runtime_name           = "python"
  runtime_version        = "3.14"
  instance_memory_in_mb  = 2048
  maximum_instance_count = 1

  app_settings = {
    CLUSTER = var.cluster.id
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

action "local_command" "deploy" {
  config {
    working_directory = path.module

    command = "sh"
    arguments = ["-c", <<EOT
        set -eu
        az functionapp deployment source config-zip \
          --name ${azurerm_function_app_flex_consumption.this.name} \
          --resource-group ${azurerm_function_app_flex_consumption.this.resource_group_name} \
          --src ${basename(local.build_zip)} \
          --build-remote false
      EOT
    ]
  }
}

resource "terraform_data" "deploy" {
  triggers_replace = {
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
  }

  depends_on = [
    terraform_data.build,
    azurerm_function_app_flex_consumption.this
  ]

  lifecycle {
    action_trigger {
      events     = [before_create]
      actions    = [action.local_command.deploy]
      on_failure = taint
    }
  }
}

resource "azurerm_role_assignment" "user" {
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  scope                = var.cluster.id
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "admin" {
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = var.cluster.id
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

action "local_command" "invoke" {
  config {
    working_directory = path.module

    command = "sh"
    arguments = ["-c", <<EOT
        set -eu
        KEY=""
        for attempt in $(seq 1 20); do
          KEY=$(az functionapp keys list \
            --name ${azurerm_function_app_flex_consumption.this.name} \
            --resource-group ${azurerm_function_app_flex_consumption.this.resource_group_name} \
            --query "functionKeys.default" \
            --output tsv 2>/dev/null || true
          )
          
          if [ -n "$KEY" ]; then
            break
          fi

          echo "Waiting for function app key to be available (attempt $attempt)..."
          sleep 15
        done

        if [ -z "$KEY" ]; then
          echo "Failed to retrieve function app key after 20 attempts"
          exit 1
        fi

        OUTPUT=$(curl --fail --silent --show-error --max-time 300 --request POST \
          --header "Content-Type: application/json" \
          --header "x-functions-key: $KEY" \
          --data '{"charts": ${jsonencode(var.charts)}}' \
          "https://${azurerm_function_app_flex_consumption.this.default_hostname}/api/handler"
        )

        STATUS="$(printf '%s' "$OUTPUT" | jq -r '.status')"
        test "$STATUS" = "Provisioning successful"
      EOT
    ]
  }
}

resource "terraform_data" "invoke" {
  triggers_replace = {
    cluster_id    = var.cluster.id
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
    charts_hash   = sha256(jsonencode(var.charts))
  }

  depends_on = [terraform_data.deploy]

  lifecycle {
    action_trigger {
      events     = [after_create]
      actions    = [action.local_command.invoke]
      on_failure = taint
    }
  }
}

resource "time_sleep" "this" {
  count           = var.sleep != null ? 1 : 0
  create_duration = var.sleep
  depends_on      = [terraform_data.invoke]
}
