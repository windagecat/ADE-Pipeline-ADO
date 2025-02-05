resource "azurerm_container_registry" "sa_acr" {
  name                = "acrsa${random_string.random.id}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "Basic"
}

resource "azurerm_user_assigned_identity" "sa" {
  location            = azurerm_resource_group.hub.location
  name                = "umi-sa-${random_string.random.id}"
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_role_assignment" "sa_acr" {
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.sa.principal_id
}

data "azuread_service_principal" "env_dev" {
  for_each     = { for i in local.mdp_subnets : i.devc_pj_name => i }
  display_name = "${each.value.devc_pj_name}/environmentTypes/dev"
}
data "azuread_service_principal" "env_stage" {
  for_each     = { for i in local.mdp_subnets : i.devc_pj_name => i }
  display_name = "${each.value.devc_pj_name}/environmentTypes/stage"
}
data "azuread_service_principal" "env_prod" {
  for_each     = { for i in local.mdp_subnets : i.devc_pj_name => i }
  display_name = "${each.value.devc_pj_name}/environmentTypes/prod"
}

resource "azurerm_role_assignment" "env_dev_umi_ope" {
  for_each             = { for i in local.mdp_subnets : i.devc_pj_name => i }
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = data.azuread_service_principal.env_dev[each.key].object_id
}
resource "azurerm_role_assignment" "env_stage_umi_ope" {
  for_each             = { for i in local.mdp_subnets : i.devc_pj_name => i }
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = data.azuread_service_principal.env_stage[each.key].object_id
}
resource "azurerm_role_assignment" "env_prod_umi_ope" {
  for_each             = { for i in local.mdp_subnets : i.devc_pj_name => i }
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = data.azuread_service_principal.env_prod[each.key].object_id
}

#data "azurerm_resources" "resources" {
#  resource_group_name = azurerm_resource_group.hub.name
#}

#output resources {
#    value = data.azurerm_resources.resources
#}