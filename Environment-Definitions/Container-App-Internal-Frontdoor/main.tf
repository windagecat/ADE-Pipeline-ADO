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
variable ade_subscription {
  type = string
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
    {
      name = "privatelink"
      subnet_address = "10.0.2.0/28"
    },
  ]
  ace-domain-split = split(".", azurerm_container_app_environment.aca_environment.default_domain)
  sa_umi = [for i in data.azurerm_resources.resources.resources : i.name if length(regexall("umi-sa-", i.name)) > 0]
  sa_acr = [for i in data.azurerm_resources.resources.resources : i.name if length(regexall("acrsa", i.name)) > 0]
  private_endpoint_connections = data.azurerm_private_link_service_endpoint_connections.frd_connection.private_endpoint_connections
  last_index = length(local.private_endpoint_connections) - 1
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
  private_link_service_network_policies_enabled  = each.value.name == "privatelink" ? false : true
}

resource "azurerm_container_app_environment" "aca_environment" {
  name                = "cae-${data.azurerm_resource_group.rg.name}"
  location            = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id = azurerm_subnet.aca_subnets["aca"].id
  internal_load_balancer_enabled = true
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

# Frontdoorでプライベートリンクする場合、プライベートDNSゾーンは不要みたい
#resource "azurerm_private_dns_zone" "dns_zone" {
#  name                = azurerm_container_app_environment.aca_environment.default_domain
#  resource_group_name = data.azurerm_resource_group.rg.name
#}

#resource "azurerm_private_dns_a_record" "dns_a_record" {
#  name                = element(split(".", azurerm_container_app.aca.ingress[0].fqdn), 0)
#  zone_name           = azurerm_private_dns_zone.dns_zone.name
#  resource_group_name = data.azurerm_resource_group.rg.name
#  ttl                 = 300
#  records             = [azurerm_container_app_environment.aca_environment.platform_reserved_dns_ip_address]
#}

#resource "azurerm_private_dns_zone_virtual_network_link" "virtual_network_link" {
#  name                  = "aca-vnet"
#  resource_group_name   = data.azurerm_resource_group.rg.name
#  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
#  virtual_network_id    = azurerm_virtual_network.aca_vnet.id
#}

data "azurerm_lb" "ace_k8s_lb" {
  name                = "kubernetes-internal"
  resource_group_name = "MC_${local.ace-domain-split[0]}-rg_${local.ace-domain-split[0]}_${local.ace-domain-split[1]}"
}

resource "azurerm_private_link_service" "pvlk" {
  name                = "pvlk-${data.azurerm_resource_group.rg.name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location == "" ? data.azurerm_resource_group.rg.location : var.location

  auto_approval_subscription_ids              = [var.ade_subscription]
  visibility_subscription_ids                 = [var.ade_subscription]
  load_balancer_frontend_ip_configuration_ids = [data.azurerm_lb.ace_k8s_lb.frontend_ip_configuration[0].id]

  nat_ip_configuration {
    name                       = "primary"
    subnet_id                  = azurerm_subnet.aca_subnets["privatelink"].id
    primary                    = true
  } 
}

resource "azurerm_cdn_frontdoor_profile" "profile" {
  name                = "afd-${data.azurerm_resource_group.rg.name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Premium_AzureFrontDoor"
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
  private_link {
    request_message        = "Request access for Private Link Origin CDN Frontdoor"
    location               = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
    private_link_target_id = azurerm_private_link_service.pvlk.id
  }
  depends_on = [azurerm_private_link_service.pvlk]
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

data "azurerm_private_link_service_endpoint_connections" "frd_connection" {
  service_id          = azurerm_private_link_service.pvlk.id
  resource_group_name = data.azurerm_resource_group.rg.name
  depends_on = [azurerm_cdn_frontdoor_origin.origin]
}

resource "null_resource" "pvlk_approve" {
  provisioner "local-exec" {
    command = "az login --identity"
  }

  provisioner "local-exec" {
    command = "az network private-endpoint-connection approve --id ${local.private_endpoint_connections[local.last_index].connection_id} --description 'Approved'"
  }
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