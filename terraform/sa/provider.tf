terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~>1.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>3.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~>2.3.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
  subscription_id = local.subscription_id
}

data "azurerm_subscription" "current" {
}

provider "azuread" {
}

provider "external" {
}

data "azuread_client_config" "current" {
}
