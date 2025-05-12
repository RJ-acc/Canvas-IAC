terraform {
  required_version = ">= 0.12"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
  }
}