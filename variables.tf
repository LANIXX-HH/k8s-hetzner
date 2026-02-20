variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "fsn1"
}

variable "control_plane_server_type" {
  description = "Server type for control plane nodes"
  type        = string
  default     = "cpx11"
}

variable "control_plane_count" {
  description = "Number of control plane nodes (3 for HA)"
  type        = number
  default     = 3
}

variable "worker_server_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cpx21"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "nginx_domain" {
  description = "Domain for nginx example app"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
}

variable "ccm_version" {
  description = "Hetzner Cloud Controller Manager version"
  type        = string
  default     = "v1.19.0"
}

variable "kured_version" {
  description = "Kured (Kubernetes Reboot Daemon) version"
  type        = string
  default     = "1.15.0"
}
