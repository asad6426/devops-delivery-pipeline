output "namespace" {
  value = kubernetes_namespace.delivery.metadata[0].name
}
