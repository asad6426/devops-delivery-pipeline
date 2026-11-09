variable "kubeconfig_path" {
  description = "Path to the kubeconfig for the target cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "environment" {
  description = "Environment name passed to the application"
  type        = string
  default     = "ci"
}
