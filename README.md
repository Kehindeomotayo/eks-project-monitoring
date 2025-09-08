# EKS 3-Tier Web Application with HIPAA Compliance

## Architecture Overview

This project deploys a comprehensive EKS-based infrastructure with:

- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **EKS Cluster**: Kubernetes 1.31 with encryption and logging
- **RDS PostgreSQL**: Encrypted database with monitoring
- **Monitoring**: Prometheus & Grafana stack
- **Logging**: EFK stack (Elasticsearch, Filebeat, Kibana)
- **GitOps**: ArgoCD for continuous deployment
- **Autoscaling**: Karpenter for pod autoscaling
- **Backup**: Velero with S3 backend
- **Security**: HIPAA compliance features

## Prerequisites

- AWS CLI configured
- Terraform >= 1.3.0
- kubectl
- Helm

## Deployment Steps

### 1. Deploy Infrastructure

```bash
cd eks-terraform
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name my-dev-eks-cluster
```

### 3. Apply Post-Deployment Configuration

```bash
# Create secure namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: secure-workloads
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

# Apply network policies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
EOF

# Apply Karpenter configuration
kubectl apply -f k8s-manifests/karpenter-nodepool.yaml

# Apply Velero schedules
kubectl apply -f k8s-manifests/velero-schedule.yaml
```

### 4. Access Services

Get service endpoints:
```bash
# ArgoCD
kubectl get svc argocd-server -n argocd

# Grafana
kubectl get svc kube-prometheus-stack-grafana -n monitoring

# Kibana
kubectl get svc kibana-kibana -n logging
```

Get ArgoCD admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## HIPAA Compliance Features

- **Encryption**: EKS secrets, RDS, S3 buckets encrypted with KMS
- **Audit Logging**: VPC Flow Logs, EKS control plane logs
- **Network Security**: Security groups, NACLs, network policies
- **Access Control**: IAM roles, RBAC, pod security standards
- **Monitoring**: Comprehensive logging and monitoring stack
- **Backup**: Automated Velero backups to encrypted S3

## Cost Optimization

- Single NAT Gateway (can be changed to multi-AZ for HA)
- RDS free tier instance
- Spot instances supported via Karpenter
- Automated resource cleanup via Velero

## Security Best Practices

- Private subnets for worker nodes
- Encrypted storage and secrets
- Network policies for micro-segmentation
- Pod security standards enforcement
- Runtime security with Falco
- Regular automated backups

## Monitoring & Observability

- **Metrics**: Prometheus + Grafana
- **Logs**: Elasticsearch + Filebeat + Kibana
- **Alerts**: AlertManager integration
- **Dashboards**: Pre-configured Grafana dashboards

## Backup & Recovery

- Daily backups at 2 AM (30-day retention)
- Weekly backups on Sunday (90-day retention)
- S3 backend with versioning and encryption
- Cross-region replication available

## Troubleshooting

1. **Cluster not accessible**: Check security groups and VPC configuration
2. **Pods not scheduling**: Verify Karpenter configuration and node capacity
3. **Services not accessible**: Check LoadBalancer and security group rules
4. **Backup failures**: Verify Velero IAM permissions and S3 access

## Cleanup

```bash
terraform destroy -var-file="dev.tfvars"
```

Note: Manually delete any LoadBalancer services before destroying to avoid orphaned AWS resources.