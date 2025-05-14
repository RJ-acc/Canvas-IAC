variable "cluster_name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "oda-canvas-eks"
}

variable "aws_region" {
  default = "us-east-2"
  description = "aws region"
}
