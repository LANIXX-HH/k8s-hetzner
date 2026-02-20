# Hetzner Kubernetes Cluster with Terraform

Complete Terraform setup for deploying a production-ready Kubernetes cluster on Hetzner Cloud with automatic TLS certificates via Let's Encrypt.

## Features

- **High Availability K3s Cluster** - 3 control plane nodes + 2 worker nodes
- **Hetzner Cloud Integration** - CCM (Cloud Controller Manager) and CSI (Container Storage Interface)
- **Traefik Ingress Controller** - Pre-configured with TLS support
- **cert-manager** - Automatic Let's Encrypt SSL certificates
- **Example nginx Application** - Ready-to-deploy Helm chart with HTTPS

## Prerequisites

- [Hetzner Cloud Account](https://www.hetzner.com/cloud)
- Domain name with DNS access
- SSH key pair (`~/.ssh/id_ed25519.pub` or customize path)

### Required Tools

Install the following tools before deployment:

**Terraform** (>= 1.5.0)
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/
```

**tfenv** (Terraform version manager - optional)
```bash
# macOS
brew install tfenv

# Linux
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
```

**Packer** (>= 1.9.0)
```bash
# macOS
brew install packer

# Linux
wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
unzip packer_1.10.0_linux_amd64.zip && sudo mv packer /usr/local/bin/
```

**kubectl**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

**hcloud CLI**
```bash
# macOS
brew install hcloud

# Linux
wget https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
tar xvzf hcloud-linux-amd64.tar.gz && sudo mv hcloud /usr/local/bin/
```

## Quick Start

### 1. Get Hetzner API Token

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create a new project or select existing one
3. Go to **Security** → **API Tokens**
4. Generate a new token with **Read & Write** permissions

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
hcloud_token      = "YOUR_HETZNER_API_TOKEN"
nginx_domain      = "k8s.yourdomain.com"
letsencrypt_email = "your-email@example.com"
```

### 3. Configure DNS

Point your domain to the Hetzner Load Balancer IP (you'll get this after deployment):

```
A    k8s.yourdomain.com    →    <LOAD_BALANCER_IP>
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply
```

### 5. Access Your Cluster

```bash
# Save kubeconfig
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

### 6. Get Load Balancer IP

```bash
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Update your DNS A record with this IP.

### 7. Verify nginx Application

Wait 2-3 minutes for cert-manager to issue the certificate, then visit:

```
https://k8s.yourdomain.com
```

You should see the nginx example page with a valid SSL certificate.

## Architecture

```
┌─────────────────────────────────────────────┐
│         Hetzner Cloud Load Balancer         │
│              (Public IP)                    │
└──────────────────┬──────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │   Traefik Ingress │
         │   (TLS Termination)│
         └─────────┬─────────┘
                   │
         ┌─────────┴─────────┐
         │  nginx Service    │
         │  (ClusterIP)      │
         └─────────┬─────────┘
                   │
         ┌─────────┴─────────┐
         │  nginx Pods (x2)  │
         └───────────────────┘

Control Plane: 3x cpx11 (2 vCPU, 2GB RAM)
Workers:       2x cpx21 (3 vCPU, 4GB RAM)
```

## Configuration Options

### Cluster Sizing

Edit `terraform.tfvars`:

```hcl
# Control plane
control_plane_server_type = "cpx11"  # cpx11, cpx21, cpx31
control_plane_count       = 3        # 1 or 3 (HA)

# Workers
worker_server_type = "cpx21"  # cpx11, cpx21, cpx31, cpx41
worker_count       = 2        # 1-10+
```

### Location

Available locations: `fsn1` (Falkenstein), `nbg1` (Nuremberg), `hel1` (Helsinki)

```hcl
location = "fsn1"
```

## Deploying Your Own Applications

### Using Helm

```bash
# Example: Deploy another app
helm install my-app ./my-chart \
  --set ingress.host=app.yourdomain.com \
  --set ingress.email=your-email@example.com
```

### Using kubectl

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - app.yourdomain.com
    secretName: my-app-tls
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Troubleshooting

### Certificate Not Issued

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate nginx-example-tls

# Check challenge status
kubectl get challenges
```

### DNS Issues

```bash
# Verify DNS propagation
dig k8s.yourdomain.com +short

# Should return your load balancer IP
```

### Cluster Access Issues

```bash
# Re-export kubeconfig
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Test connection
kubectl cluster-info
```

## Cost Estimation

Monthly costs (as of 2026):

- 3x cpx11 (control plane): ~€15
- 2x cpx21 (workers): ~€18
- Load Balancer: ~€5
- **Total: ~€38/month**

Use [Hetzner Pricing Calculator](https://www.hetzner.com/cloud#pricing) for exact pricing.

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

**Warning:** This will delete the entire cluster and all data.

## Security Notes

- SSH access is restricted to your public key
- All traffic is encrypted with TLS
- Keep your `terraform.tfvars` secure (contains API token)
- Add `terraform.tfvars` to `.gitignore`

## Project Structure

```
.
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Variable definitions
├── outputs.tf                       # Output definitions
├── terraform.tfvars.example         # Example variables
├── terraform.tfvars                 # Your variables (git-ignored)
└── helm/
    └── nginx-example/
        ├── Chart.yaml               # Helm chart metadata
        ├── values.yaml              # Default values
        └── templates/
            ├── deployment.yaml      # nginx deployment
            ├── service.yaml         # ClusterIP service
            ├── ingress.yaml         # Traefik ingress with TLS
            ├── clusterissuer.yaml   # Let's Encrypt issuer
            └── configmap.yaml       # HTML content
```

## Next Steps

- Add monitoring with Prometheus/Grafana
- Set up automated backups with Velero
- Configure horizontal pod autoscaling
- Add additional applications
- Set up CI/CD pipelines

## Resources

- [kube-hetzner Documentation](https://github.com/kube-hetzner/kube-hetzner)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## License

MIT
