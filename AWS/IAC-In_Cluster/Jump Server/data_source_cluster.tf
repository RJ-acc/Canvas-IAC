############################################
# Fetch EKS endpoint, CA bundle and a token
############################################
variable "cluster_name" {}
variable "aws_region"   {}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}
