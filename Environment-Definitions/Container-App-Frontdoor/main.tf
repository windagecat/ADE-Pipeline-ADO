#プロバイダー定義
terraform {
  required_providers {
     azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

#変数定義
variable location {
  type = string
  default = ""
}
variable resource_group_name {
  type = string
}
variable LogRetentionInDays {
  type    = number
  default = 30
}
variable containerImage {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}
variable cpuCore {
  type = string
  default = "0.5"
  validation {
    condition     = contains(["0.25", "0.5", "0.75", "1", "1.25", "1.5", "1.75", "2"], var.cpuCore)
    error_message = "The cpuCore must be one of: 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2"
  }
}
variable memorySize {
  type = string
  default = "1"
  validation {
    condition     = contains(["0.5", "1", "1.5", "2", "3", "3.5", "4"], var.memorySize)
    error_message = "The memorySize must be one of: 0.5, 1, 1.5, 2, 3, 3.5, 4"
  }
}
variable minReplicas {
  type    = number
  default = 1 
}
variable maxReplicas {
  type    = number
  default = 3
}
variable targetPort {
  type    = number
  default = 80
}

locals {
  vnet_cidr = "10.0.0.0/16"
  subnets = [
    {
      name = "aca"
      subnet_address = "10.0.0.0/23"
    },
  ]
  sa_umi = [for i in data.azurerm_resources.resources.resources : i.name if length(regexall("umi-sa-", i.name)) > 0]
  sa_acr = [for i in data.azurerm_resources.resources.resources : i.name if length(regexall("acrsa", i.name)) > 0]
}

#リソース

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_resources" "resources" {
  resource_group_name = "hub-ade"
}

data "azurerm_user_assigned_identity" "aca" {
  name                = local.sa_umi[0]
  resource_group_name = "hub-ade"
}

data "azurerm_container_registry" "aca" {
  name                = local.sa_acr[0]
  resource_group_name = "hub-ade"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${data.azurerm_resource_group.rg.name}"
  location            = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.LogRetentionInDays  
}

resource "azurerm_virtual_network" "aca_vnet" {
  name                = "vnet-${data.azurerm_resource_group.rg.name}"
  address_space       = [local.vnet_cidr]
  location            = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
  resource_group_name = data.azurerm_resource_group.rg.name  
}

resource "azurerm_subnet" "aca_subnets" {
  for_each              = { for i in local.subnets : i.name => i }
  name                  = "snet-${each.value.name}"
  resource_group_name   = data.azurerm_resource_group.rg.name
  virtual_network_name  = azurerm_virtual_network.aca_vnet.name
  address_prefixes      = [each.value.subnet_address]
}

resource "azurerm_container_app_environment" "aca_environment" {
  name                = "cae-${data.azurerm_resource_group.rg.name}"
  location            = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id = azurerm_subnet.aca_subnets["aca"].id
}

resource "azurerm_container_app" "aca" {
  name                         = "aca-${data.azurerm_resource_group.rg.name}"
  container_app_environment_id = azurerm_container_app_environment.aca_environment.id
  resource_group_name          = data.azurerm_resource_group.rg.name
  revision_mode                = "Single"
  ingress {
      allow_insecure_connections = false
      external_enabled           = true
      target_port                = var.targetPort
      traffic_weight {
        latest_revision = true
        percentage      = 100
      }
  }
  template {
    #revision_suffix = "firstrevision"
    container {
      name   = "app-${data.azurerm_resource_group.rg.name}"
      image  = var.containerImage
      cpu    = var.cpuCore
      memory = "${var.memorySize}Gi"
    }
    max_replicas = var.maxReplicas
    min_replicas = var.minReplicas
  }
  identity {
    type = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.aca.id]
  }
  registry {
    server = data.azurerm_container_registry.aca.login_server
    identity = data.azurerm_user_assigned_identity.aca.id
  }
}

resource "azurerm_cdn_frontdoor_profile" "profile" {
  name                = "afd-${data.azurerm_resource_group.rg.name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"  
}

resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "fde-${data.azurerm_resource_group.rg.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id  
}

resource "azurerm_cdn_frontdoor_origin_group" "origin_group" { 
  name                     = "origin-group-aca"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id
  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }
  load_balancing {}
}

resource "azurerm_cdn_frontdoor_origin" "origin" {  
  name                          = "origin-aca"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group.id
  host_name                      = azurerm_container_app.aca.ingress[0].fqdn
  origin_host_header             = azurerm_container_app.aca.ingress[0].fqdn
  certificate_name_check_enabled = true
  enabled                        = true
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000
}

resource "azurerm_cdn_frontdoor_route" "route" { 
  name                          = "route-aca"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origin.id]

  patterns_to_match   = ["/*"]
  supported_protocols = ["Http","Https"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
}

resource "azurerm_monitor_diagnostic_setting" "fd-law" {
  name               = "send-to-law"
  target_resource_id = azurerm_cdn_frontdoor_profile.profile.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  enabled_log {
    category_group  = "allLogs"
  }
  metric {
    category = "AllMetrics"
    enabled  = false 
  }
}