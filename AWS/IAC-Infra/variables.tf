variable "cluster_name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "oda-canvas-eks"
}

variable "k8s_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/24"
}

variable "aws_region" {
  default = "us-east-1"
  description = "aws region"
}


variable "istio_chart_version" {
  description = "Istio Helm Chart version , checked on 12 May 2025"
  default     = "1.26.0"
  type        = string
}

variable "canvas_chart_repo" {
  description = "Canvas  Chart Repo , not hardcoded as separate repo for testing can be used"
  default     = "https://tmforum-oda.github.io/oda-canvas"
  type        = string
}
