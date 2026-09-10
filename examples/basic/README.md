# Basic Bootstrap Example
This example demonstrates how to use the `terraform-azurerm-kubernetes-bootstrap` module to install Helm charts into a AKS cluster.

### Login
Login to your Azure account using the cloud CLI before running the Terraform commands.
```bash
az login
```

### Apply
Run the following commands to initialize the Terraform, create an execution plan, and apply the infrastructure.
```bash
terraform init
terraform plan
terraform apply
```

After the AKS cluster is created, the module invokes the Function App to connect to the Kubernetes API and install Helm charts.

### Verification
Run the following command to verify that the Helm chart was installed successfully.
```bash
az aks command invoke --resource-group example-resources --name example-cluster --command "kubectl get pods --namespace monitoring"
```

You should see the `grafana` pod running in the cluster.

### Cleanup
```bash
terraform destroy
```

Make sure to cleanup the Function App and any other resources created by the module to avoid incurring unnecessary costs.
