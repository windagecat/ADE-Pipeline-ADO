locals {
  current_azuredevops_users = tolist(data.azuredevops_users.current.users)
}
data "azuread_user" "current" {
  object_id = data.azuread_client_config.current.object_id
}

data "azuredevops_users" "current" {
  principal_name = data.azuread_user.current.user_principal_name
}

data "azuredevops_group" "contributors" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  name       = "Contributors"
}

data "azuredevops_group" "readers" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  name       = "Readers"
}

resource "azuredevops_team" "sa" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  name       = "sa-${random_string.random.id}"
  administrators = [
    local.current_azuredevops_users[0].descriptor
  ]
  members = [
    local.current_azuredevops_users[0].descriptor,
    azuredevops_service_principal_entitlement.logicapp_delete_env_aca[each.key].descriptor
  ]
}

resource "azuredevops_group_membership" "contributors" {
  for_each = { for i in local.mdp_subnets : i.ado_pj_name => i }
  group    = data.azuredevops_group.contributors[each.key].descriptor
  members = [
    azuredevops_team.sa[each.key].descriptor
  ]
}
resource "azuredevops_branch_policy_build_validation" "pr_stage_env" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  enabled    = true
  blocking   = true

  settings {
    display_name                = "PR-Stage-Env"
    build_definition_id         = azuredevops_build_definition.create-env_deploy-aca[each.key].id
    queue_on_source_update_only = false
    valid_duration              = 0
    filename_patterns = [
      "/src/*",
    ]

    scope {
      repository_id  = data.azuredevops_git_repository.sa[each.key].id
      repository_ref = data.azuredevops_git_repository.sa[each.key].default_branch
      match_type     = "Exact"
    }
  }
}


resource "azuredevops_branch_policy_auto_reviewers" "auto_reviewers" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id
  enabled    = true
  blocking   = true

  settings {
    auto_reviewer_ids  = [azuredevops_team.sa[each.key].id]
    submitter_can_vote = true
    #message            = "Auto reviewer"
    path_filters = ["/src/*"]

    scope {
      repository_id  = data.azuredevops_git_repository.sa[each.key].id
      repository_ref = data.azuredevops_git_repository.sa[each.key].default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_merge_types" "merge_type" {
  for_each   = { for i in local.mdp_subnets : i.ado_pj_name => i }
  project_id = data.azuredevops_project.sa_pj[each.key].id

  enabled  = true
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = data.azuredevops_git_repository.sa[each.key].id
      repository_ref = data.azuredevops_git_repository.sa[each.key].default_branch
      match_type     = "Exact"
    }
  }
}
