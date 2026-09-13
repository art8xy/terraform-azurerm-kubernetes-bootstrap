# Azure Kubernetes Bootstrap
The `terraform-azurerm-kubernetes-bootstrap` module simplifies private bootstrapping of AKS clusters.  
The module uses a serverless Function App to configure the Kubernetes cluster and install Helm charts.  
The Function is deployed inside the AKS VNet, allowing it to access the Kubernetes API without exposing it publicly.

### Features
* Deploys a Function App inside the AKS VNet
* Supports private access to the Kubernetes API
* Authenticates to AKS using Azure Managed Identity
* Installs and manages Helm charts
* Keeps Kubernetes bootstrap operations within Azure

### How it works
Terraform creates the Function App, required RBAC and VNet access configuration.  
After deployment, Terraform invokes the function with the configured Helm charts.

![Architecture](https://raw.githubusercontent.com/art8xy/terraform-azurerm-kubernetes-bootstrap/main/assets/images/architecture.png)

The Function App:
1. Retrieves the AKS cluster configuration.
2. Generates an AKS authentication token.
3. Configures a temporary kubeconfig.
4. Connects to the Kubernetes API.
5. Installs the configured Helm charts.

This makes it possible to provision and bootstrap private AKS clusters entirely through Terraform, without exposing the Kubernetes API publicly or requiring the Terraform execution environment to have network access to the cluster.

### Prerequisites
The following tools must be installed in the environment running Terraform.  
They are used to build and package the Function App deployment artifact:
- `zip`
- `tar`
- `curl`
- `pip3`
- `python3`

### Example
Below is a basic example of how to use the module to install the `grafana` Helm chart.
```hcl
module "bootstrap" {
  source = "art8xy/kubernetes-bootstrap/azurerm"
  version = "1.0.0"

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
```
