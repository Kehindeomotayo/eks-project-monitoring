# ArgoCD for GitOps
resource "helm_release" "argocd" {
  namespace        = "argocd"
  create_namespace = true
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.0"
  timeout          = 600
  wait             = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
        }
        extraArgs = [
          "--insecure"
        ]
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [aws_eks_node_group.eks_nodes_1]
}

# ArgoCD Application for the 3-tier app (apply manually after cluster is ready)
# kubectl apply -f - <<EOF
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: three-tier-app
#   namespace: argocd
# spec:
#   project: default
#   source:
#     repoURL: https://github.com/holadmex/eks-project.git
#     targetRevision: HEAD
#     path: k8s-manifests
#   destination:
#     server: https://kubernetes.default.svc
#     namespace: default
#   syncPolicy:
#     automated:
#       prune: true
#       selfHeal: true
#     syncOptions:
#     - CreateNamespace=true
# EOF