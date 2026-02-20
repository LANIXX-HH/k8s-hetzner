terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}


resource "local_file" "snapshot_id" {
  filename   = "${path.module}/snapshot_id.txt"
  content    = "0"
}


resource "null_resource" "packer_build" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p packer 
      cd packer
      curl -sL https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/packer-template/hcloud-microos-snapshots.pkr.hcl -o hcloud-microos-snapshots.pkr.hcl
      packer init hcloud-microos-snapshots.pkr.hcl
      packer build -var hcloud_token=${var.hcloud_token} hcloud-microos-snapshots.pkr.hcl
      hcloud image list -o noheader -o columns=id -l microos-snapshot=yes | head -n1 > ${path.module}/snapshot_id.txt
    EOT
    environment = {
      HCLOUD_TOKEN = var.hcloud_token
    }
  }

  triggers = {
    packer_template = filemd5("${path.module}/packer/hcloud-microos-snapshots.pkr.hcl")
  }
  depends_on = [ local_file.snapshot_id ]
}

module "kube-hetzner" {
  providers = {
    hcloud = hcloud
  }

  source  = "kube-hetzner/kube-hetzner/hcloud"
  version = "2.14.3"

  hcloud_token = var.hcloud_token

  ssh_private_key = file(var.ssh_private_key_path)
  ssh_public_key  = file(var.ssh_public_key_path)
  ssh_additional_public_keys = [file(var.ssh_public_key_path)]

  microos_x86_snapshot_id = trimspace(local_file.snapshot_id.content)

  use_cluster_name_in_node_name = var.use_cluster_name_in_node_name
  automatically_upgrade_os      = var.automatically_upgrade_os

  hetzner_ccm_version = var.ccm_version
  kured_version       = var.kured_version
  traefik_version     = var.traefik_version

  control_plane_nodepools = [
    {
      name        = "control-plane"
      server_type = var.control_plane_server_type
      location    = var.location
      labels      = []
      taints      = []
      count       = var.control_plane_count
    }
  ]

  agent_nodepools = [
    {
      name        = "worker"
      server_type = var.worker_server_type
      location    = var.location
      labels      = []
      taints      = []
      count       = var.worker_count
    }
  ]

  depends_on = [null_resource.packer_build]
}

resource "null_resource" "nginx_example" {
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${path.module}/k3s_kubeconfig.yaml
      kubectl apply -f - <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nginx-example
  namespace: kube-system
spec:
  chart: ${var.nginx_chart_name}
  repo: ${var.nginx_chart_repo}
  targetNamespace: ${var.nginx_namespace}
  valuesContent: |-
    service:
      type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-example
  namespace: ${var.nginx_namespace}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - ${var.nginx_domain}
    secretName: nginx-example-tls
  rules:
  - host: ${var.nginx_domain}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-example
            port:
              number: 80
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: ${var.letsencrypt_server}
    email: ${var.letsencrypt_email}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
    EOT
  }

  depends_on = [module.kube-hetzner]
}
