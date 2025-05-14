############################################
# versions.tf  – run from the jump box
############################################
terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34"   
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2"      
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8"     
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
  }
}
