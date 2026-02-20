output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.kube-hetzner.kubeconfig
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.kube-hetzner.kubeconfig_data.host
  sensitive   = true
}

output "nginx_url" {
  description = "URL for nginx example application"
  value       = "https://${var.nginx_domain}"
}
