resource "azurerm_resource_group" "hub" {
  name     = "hub-ade"
  location = "eastasia"
}

resource "random_string" "random" {
  length      = 4
  special     = false
  upper       = false
  min_lower   = 1
  min_numeric = 1
  keepers = {
    rg_name = azurerm_resource_group.hub.name
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${random_string.random.keepers.rg_name}-${random_string.random.id}"
  address_space       = [local.vnet_cidr]
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

data "azuread_service_principal" "devopsinfra" {
  display_name = "DevOpsInfrastructure"
}

resource "azurerm_role_assignment" "devopsinfra_rd" {
  scope                = azurerm_virtual_network.hub.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.devopsinfra.object_id
}

resource "azurerm_role_assignment" "devopsinfra_nc" {
  scope                = azurerm_virtual_network.hub.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.devopsinfra.object_id
}

resource "azurerm_subnet" "mdp_subnets" {
  for_each             = { for i in local.mdp_subnets : i.devc_pj_name => i }
  name                 = "snet-${each.value.devc_pj_name}-mdp-${random_string.random.id}"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value.subnet_address]
  delegation {
    name = "mdp-delegation"
    service_delegation {
      name    = "Microsoft.DevOpsInfrastructure/pools"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "managed_subnets" {
  for_each             = { for i in local.managed_subnets : i.name => i }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value.subnet_address]
}

resource "azapi_resource" "mdps" {
  for_each  = { for i in local.mdp_subnets : i.devc_pj_name => i }
  type      = "Microsoft.DevOpsInfrastructure/pools@2024-04-04-preview"
  parent_id = azurerm_resource_group.hub.id
  name      = "mdp-${each.value.devc_pj_name}-${random_string.random.id}"
  location  = azurerm_resource_group.hub.location
  body = {
    properties = {
      agentProfile = {
        gracePeriodTimeSpan = "00:00:00"
        kind                = "Stateful"
        maxAgentLifetime    = "7.00:00:00"
        resourcePredictionsProfile = {
          kind                 = "Automatic"
          predictionPreference = "BestPerformance"
        }
      }
      devCenterProjectResourceId = "/subscriptions/${local.subscription_id}/resourceGroups/${local.devcenter.devcenter_rg}/providers/Microsoft.DevCenter/projects/${each.value.devc_pj_name}"
      fabricProfile = {
        images = [
          {
            aliases = [
              "ubuntu-22.04"
            ]
            buffer             = "*"
            wellKnownImageName = "ubuntu-22.04/latest"
          }
        ]
        kind = "Vmss"
        networkProfile = {
          subnetId = azurerm_subnet.mdp_subnets[each.key].id
        }
        osProfile = {
          logonType = "Interactive"
          secretsManagementSettings = {
            keyExportable        = false
            observedCertificates = []
          }
        }
        sku = {
          name = "Standard_B2ms"
        }
        storageProfile = {
          dataDisks                = []
          osDiskStorageAccountType = "Standard"
        }
      }
      maximumConcurrency = 1
      organizationProfile = {
        kind = "AzureDevOps"
        organizations = [
          {
            parallelism = 1
            projects = [
              each.value.ado_pj_name
            ]
            url = "https://dev.azure.com/${local.ado_orz}"
          }
        ]
        permissionProfile = {
          kind = "Inherit"
        }
      }
      provisioningState = "Succeeded"
    }
  }
  lifecycle {
    ignore_changes = [
      body.properties.agentProfile, body.properties.fabricProfile.images, body.properties.fabricProfile.osProfile, body.properties.fabricProfile.sku, body.properties.fabricProfile.storageProfile, body.properties.maximumConcurrency
    ]
  }
  depends_on = [azurerm_role_assignment.devopsinfra_rd, azurerm_role_assignment.devopsinfra_nc]
}
