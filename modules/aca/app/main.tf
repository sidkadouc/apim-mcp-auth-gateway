# ------------------------------------------------------------------------------
# ACA container app – generic container app
# ------------------------------------------------------------------------------

resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = var.environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  dynamic "registry" {
    for_each = var.registry_server != "" ? [1] : []
    content {
      server               = var.registry_server
      username             = var.registry_username
      password_secret_name = "registry-password"
    }
  }

  dynamic "secret" {
    for_each = var.registry_server != "" ? [1] : []
    content {
      name  = "registry-password"
      value = var.registry_password
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  ingress {
    external_enabled = var.external_ingress
    target_port      = var.target_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
