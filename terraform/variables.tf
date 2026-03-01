# =============================================================
# OmniNode — Terraform Variables
# =============================================================

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "lon1"
}

variable "droplet_size" {
  description = "Droplet size — 4GB RAM minimum for running both nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "volume_size_gb" {
  description = "Blockchain data volume size in GB"
  type        = number
  default     = 100
}

variable "github_repo" {
  description = "GitHub repo to clone — format: username/repo"
  type        = string
  default     = "artcelltarafder-pixel/omninode-infrastructure"
}
