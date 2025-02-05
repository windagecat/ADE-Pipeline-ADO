variable "ado_pat" {
}
resource "azurerm_logic_app_workflow" "delete_env_aca" {
  for_each            = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name                = "delete-env-aca-${each.value.devc_pj_name}"
  location            = azurerm_resource_group.sa[each.key].location
  resource_group_name = azurerm_resource_group.sa[each.key].name
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_logic_app_trigger_http_request" "http_trigger" {
  for_each     = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name         = "When a HTTP request is received"
  method       = "POST"
  logic_app_id = azurerm_logic_app_workflow.delete_env_aca[each.key].id
  schema       = jsonencode(jsondecode(file("${path.module}/files/logicapp/trigger_schema.json")))
}

resource "azurerm_logic_app_action_custom" "variable" {
  for_each     = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name         = "ado"
  logic_app_id = azurerm_logic_app_workflow.delete_env_aca[each.key].id

  body = jsonencode(jsondecode(templatefile("${path.module}/files/logicapp/action_variables.json",
    {
      organization         = local.ado_orz
      ado_pj               = each.value.ado_pj_name
      delete_definition_id = azuredevops_build_definition.delete-env-aca[each.key].id
    }
  )))
}

resource "azurerm_logic_app_action_custom" "http" {
  for_each     = { for i in local.mdp_subnets : i.ado_pj_name => i }
  name         = "ビルドキュー実行"
  logic_app_id = azurerm_logic_app_workflow.delete_env_aca[each.key].id

  body = jsonencode(jsondecode(templatefile("${path.module}/files/logicapp/action_http.json",
    {
      variable_action_name = azurerm_logic_app_action_custom.variable[each.key].name
    }
  )))
}

resource "azuredevops_service_principal_entitlement" "logicapp_delete_env_aca" {
  for_each  = { for i in local.mdp_subnets : i.ado_pj_name => i }
  origin_id = azurerm_logic_app_workflow.delete_env_aca[each.key].identity[0].principal_id
  origin    = "aad"
}

data "external" "logicapp_service_hook" {
  for_each = { for i in local.mdp_subnets : i.ado_pj_name => i }
  program  = ["bash", "${path.module}/files/servicehook/logicapp_service_hook_v2.sh"]

  query = {
    ado_projectId     = data.azuredevops_project.sa_pj[each.key].id
    ado_team_group_id = azuredevops_team.sa[each.key].id
    ado_repo_id       = data.azuredevops_git_repository.sa[each.key].id
    webhook_url       = azurerm_logic_app_trigger_http_request.http_trigger[each.key].callback_url
    pat               = var.ado_pat
    orgnization       = local.ado_orz
  }
}

resource "null_resource" "delete_logicapp_service_hook" {
  for_each = { for i in local.mdp_subnets : i.ado_pj_name => i }
  triggers = {
    subscriptionid = data.external.logicapp_service_hook[each.key].result["subscriptionid"]
    orgnization    = local.ado_orz
    pat            = var.ado_pat
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      curl -s -X DELETE \
      -u :${self.triggers.pat} \
      https://dev.azure.com/${self.triggers.orgnization}/_apis/hooks/subscriptions/${self.triggers.subscriptionid}?api-version=7.1
    EOT
  }
}

