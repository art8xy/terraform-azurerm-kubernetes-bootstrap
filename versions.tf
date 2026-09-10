terraform {
  required_version = ">= 1.16.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.14.0"
    }
  }
}
