resource "random_string" "random" {
  length      = 3
  special     = false
  upper       = false
  min_lower   = 1
  min_numeric = 1
}

data "azuredevops_project" "sa_pj" {
  for_each = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name     = each.value.ado_pj_name
}

data "azurerm_resource_group" "hub" {
  name = "hub-ade"
}

resource "azurerm_resource_group" "sa" {
  for_each = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name     = "${each.value.devc_pj_name}-${random_string.random.id}"
  location = "eastasia"
}

resource "azurerm_user_assigned_identity" "sa_workloadid" {
  for_each            = { for i in local.mdp_subnets : i.ado_pj_name => i }
  location            = azurerm_resource_group.sa[each.key].location
  name                = "workloadid-${random_string.random.id}"
  resource_group_name = azurerm_resource_group.sa[each.key].name
}

resource "azurerm_role_assignment" "sa_workloadid_ade_depen_user" {
  for_each             = { for i in local.mdp_subnets : i.ado_pj_name => i }
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${local.devcenter.devcenter_rg}/providers/Microsoft.DevCenter/projects/${each.value.devc_pj_name}"
  role_definition_name = "Deployment Environments User"
  principal_id         = azurerm_user_assigned_identity.sa_workloadid[each.key].principal_id
}

resource "azurerm_role_assignment" "sa_workloadid_acrpush" {
  for_each             = { for i in local.mdp_subnets : i.ado_pj_name => i }
  scope                = data.azurerm_resource_group.hub.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.sa_workloadid[each.key].principal_id
}

resource "azuredevops_serviceendpoint_azurerm" "sa_ade" {
  for_each                               = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id                             = data.azuredevops_project.sa_pj[each.key].id
  service_endpoint_name                  = "ade-workloadid-${random_string.random.id}"
  description                            = "Managed by Terraform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.sa_workloadid[each.key].client_id
  }
  azurerm_spn_tenantid      = data.azurerm_subscription.current.tenant_id
  azurerm_subscription_id   = data.azurerm_subscription.current.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.current.display_name
}

resource "azurerm_federated_identity_credential" "sa_ade" {
  for_each            = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name                = "federated-credential"
  resource_group_name = azurerm_resource_group.sa[each.key].name
  parent_id           = azurerm_user_assigned_identity.sa_workloadid[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].workload_identity_federation_issuer
  subject             = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].workload_identity_federation_subject
}
