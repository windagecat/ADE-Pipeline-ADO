terraform {
  required_providers {
     azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    azuread = {
      source = "hashicorp/azuread"
      version = "~>3.0.0"
    }
    azapi = {
      source = "Azure/azapi"
      version = "~>2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
  subscription_id = local.subscription_id
}

provider "azuread" {
}

provider "azapi" {
}

data "azurerm_subscription" "current" {
}
