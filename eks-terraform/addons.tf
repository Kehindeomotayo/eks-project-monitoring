# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.eks_nodes_1]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}



# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  namespace = "kube-system"
  name      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart     = "aws-load-balancer-controller"
  version   = "1.6.2"
  timeout   = 600
  wait      = true

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.eks.name
      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
        }
      }
    })
  ]

  depends_on = [aws_eks_node_group.eks_nodes_1]
}

# Create service account for AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

# # Velero Helm Chart
# resource "helm_release" "velero" {
#   namespace        = "velero"
#   create_namespace = true
#   name             = "velero"
#   repository       = "https://vmware-tanzu.github.io/helm-charts"
#   chart            = "velero"
#   version          = "5.1.0"
#   timeout          = 600
#   wait             = true

#   values = [
#     yamlencode({
#       serviceAccount = {
#         server = {
#           annotations = {
#             "eks.amazonaws.com/role-arn" = aws_iam_role.velero.arn
#           }
#         }
#       }
#       configuration = {
#         backupStorageLocation = [{
#           name     = "default"
#           provider = "aws"
#           bucket   = aws_s3_bucket.velero_backups.bucket
#           config = {
#             region = var.region
#           }
#         }]
#         volumeSnapshotLocation = [{
#           name     = "default"
#           provider = "aws"
#           config = {
#             region = var.region
#           }
#         }]
#       }
#       initContainers = [{
#         name  = "velero-plugin-for-aws"
#         image = "velero/velero-plugin-for-aws:v1.8.0"
#         volumeMounts = [{
#           mountPath = "/target"
#           name      = "plugins"
#         }]
#       }]
#     })
#   ]

#   depends_on = [aws_eks_node_group.eks_nodes_1]
# }

# # S3 Bucket for Velero backups
# resource "aws_s3_bucket" "velero_backups" {
#   bucket = "${var.cluster_name}-velero-backups-${random_id.bucket_suffix.hex}"

#   tags = {
#     Name = "${var.cluster_name}-velero-backups"
#   }
# }

# resource "random_id" "bucket_suffix" {
#   byte_length = 2
# }

# resource "aws_s3_bucket_versioning" "velero_backups" {
#   bucket = aws_s3_bucket.velero_backups.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_encryption" "velero_backups" {
#   bucket = aws_s3_bucket.velero_backups.id

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         kms_master_key_id = aws_kms_key.eks.arn
#         sse_algorithm     = "aws:kms"
#       }
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "velero_backups" {
#   bucket = aws_s3_bucket.velero_backups.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }