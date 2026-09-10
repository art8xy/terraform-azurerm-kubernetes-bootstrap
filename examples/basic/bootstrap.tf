module "bootstrap" {
  source = "../../"

  cluster = azurerm_kubernetes_cluster.this
  subnet  = "10.0.10.0/28"
  charts = {
    grafana = {
      chart      = "grafana"
      repository = "https://grafana.github.io/helm-charts"
      namespace  = "monitoring"
      values = {
        resources = {
          limits   = { cpu = "100m", memory = "128Mi" }
          requests = { cpu = "100m", memory = "128Mi" }
        }
      }
    }
  }
}
