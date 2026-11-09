provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

resource "kubernetes_namespace" "delivery" {
  metadata {
    name = "delivery"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

resource "kubernetes_resource_quota" "delivery" {
  metadata {
    name      = "delivery-quota"
    namespace = kubernetes_namespace.delivery.metadata[0].name
  }

  spec {
    hard = {
      pods              = "6"
      "requests.cpu"    = "1"
      "requests.memory" = "512Mi"
      "limits.cpu"      = "2"
      "limits.memory"   = "1Gi"
    }
  }
}

resource "kubernetes_config_map" "delivery" {
  metadata {
    name      = "delivery-config"
    namespace = kubernetes_namespace.delivery.metadata[0].name
  }

  data = {
    APP_ENVIRONMENT = var.environment
  }
}
