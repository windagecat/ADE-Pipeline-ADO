locals {
  sa_acr = [for i in data.azurerm_resources.hub_resources.resources : i.name if length(regexall("acrsa", i.name)) > 0]
}

data "azuredevops_git_repository" "sa" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  name       = each.value.ado_repo_name
}

data "azuredevops_agent_queue" "sa" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  name       = "mdp-${each.value.devc_pj_name}-${substr(data.azurerm_container_registry.aca.name, 5, 4)}"
}

data "azurerm_resources" "hub_resources" {
  resource_group_name = data.azurerm_resource_group.hub.name
}

data "azurerm_container_registry" "aca" {
  name                = local.sa_acr[0]
  resource_group_name = data.azurerm_resource_group.hub.name
}

resource "azuredevops_build_definition" "create-env_deploy-aca" {
  for_each        = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id      = data.azuredevops_project.sa_pj[each.key].id
  name            = "create-env_deploy-aca"
  agent_pool_name = data.azuredevops_agent_queue.sa[each.key].name

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = data.azuredevops_git_repository.sa[each.key].id
    branch_name = data.azuredevops_git_repository.sa[each.key].default_branch
    yml_path    = ".ado/create-env_deploy-aca.yaml"
  }
}

resource "azuredevops_build_definition" "delete-env-aca-schedule" {
  for_each        = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id      = data.azuredevops_project.sa_pj[each.key].id
  name            = "delete-env-aca-schedule"
  agent_pool_name = data.azuredevops_agent_queue.sa[each.key].name

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = data.azuredevops_git_repository.sa[each.key].id
    branch_name = data.azuredevops_git_repository.sa[each.key].default_branch
    yml_path    = ".ado/delete-env-aca-schedule.yaml"
  }
}

resource "azuredevops_build_definition" "delete-env-aca" {
  for_each        = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id      = data.azuredevops_project.sa_pj[each.key].id
  name            = "delete-env-aca"
  agent_pool_name = data.azuredevops_agent_queue.sa[each.key].name

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = data.azuredevops_git_repository.sa[each.key].id
    branch_name = data.azuredevops_git_repository.sa[each.key].default_branch
    yml_path    = ".ado/delete-env-aca.yaml"
  }

  variable {
    name  = "SourceBranch"
    value = ""
  }
}


resource "azuredevops_pipeline_authorization" "agent_create-env_deploy-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = data.azuredevops_agent_queue.sa[each.key].id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.create-env_deploy-aca[each.key].id
}

resource "azuredevops_pipeline_authorization" "agent_delete-env-aca-schedule" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = data.azuredevops_agent_queue.sa[each.key].id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.delete-env-aca-schedule[each.key].id
}

resource "azuredevops_pipeline_authorization" "agent_delete-env-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = data.azuredevops_agent_queue.sa[each.key].id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.delete-env-aca[each.key].id
}

resource "azuredevops_pipeline_authorization" "svconnection_create-env_deploy-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.create-env_deploy-aca[each.key].id
}

resource "azuredevops_pipeline_authorization" "svconnection_delete-env-aca-schedule" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.delete-env-aca-schedule[each.key].id
}

resource "azuredevops_pipeline_authorization" "svconnection_delete-env-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.delete-env-aca[each.key].id
}


resource "azuredevops_variable_group" "ade" {
  for_each     = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id   = data.azuredevops_project.sa_pj[each.key].id
  name         = "ade"
  allow_access = false

  variable {
    name  = "Acrname"
    value = data.azurerm_container_registry.aca.name
  }
  variable {
    name  = "ADO_ORGANIZATION"
    value = local.ado_orz
  }
  variable {
    name  = "ADO_PROJECT"
    value = each.value.ado_pj_name
  }
  variable {
    name  = "ADO_REPOSITORY"
    value = each.value.ado_repo_name
  }
  variable {
    name  = "Adpagentpoolname"
    value = data.azuredevops_agent_queue.sa[each.key].name
  }
  variable {
    name  = "AZURE_CATALOG"
    value = local.devcenter.devcenter_catalog
  }
  variable {
    name  = "AZURE_DEVCENTER"
    value = local.devcenter.devcenter_name
  }
  variable {
    name  = "AZURE_DEVCENTER_ENDPOINT"
    value = local.devcenter.devcenter_endpoint
  }
  variable {
    name  = "AZURE_PROJECT"
    value = each.value.devc_pj_name
  }
  variable {
    name  = "ServiceConnectionName"
    value = azuredevops_serviceendpoint_azurerm.sa_ade[each.key].service_endpoint_name
  }

}



resource "azuredevops_pipeline_authorization" "variablegp_create-env_deploy-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_variable_group.ade[each.key].id
  type        = "variablegroup"
  pipeline_id = azuredevops_build_definition.create-env_deploy-aca[each.key].id
}

resource "azuredevops_pipeline_authorization" "variablegp_delete-env-aca-schedule" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_variable_group.ade[each.key].id
  type        = "variablegroup"
  pipeline_id = azuredevops_build_definition.delete-env-aca-schedule[each.key].id
}

resource "azuredevops_pipeline_authorization" "variablegp_delete-env-aca" {
  for_each    = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id  = data.azuredevops_project.sa_pj[each.key].id
  resource_id = azuredevops_variable_group.ade[each.key].id
  type        = "variablegroup"
  pipeline_id = azuredevops_build_definition.delete-env-aca[each.key].id
}
