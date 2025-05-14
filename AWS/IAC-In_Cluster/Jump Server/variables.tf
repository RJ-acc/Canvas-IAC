variable "cluster_name" {
  description = "Name of the VPC and EKS Cluster"
  type        = string
  default     = "oda-canvas-eks"
}

variable "aws_region" {
  default = "us-east-2"
  description = "aws region"
}

variable "canvas_vault_enabled" {
  description = "Enable the internal Vault sub-chart"
  type        = bool
  default     = false
}

# Choose Any one  gateway implementation for canvas 
variable "gateway_type" {
  description = "Ingress gateway to install (istio | apisix | kong)"
  type        = string
  default     = "apisix"

  validation {
    condition     = contains(["istio", "apisix", "kong"], var.gateway_type)
    error_message = "gateway_type must be any one of istio, apisix or kong."
  }
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