import os
import yaml
import logging
from pathlib import Path

from azure.identity import DefaultAzureCredential
from azure.mgmt.containerservice import ContainerServiceClient

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_CREDENTIALS = DefaultAzureCredential()

def config(tmp: Path, cluster: str) -> None:
    workdir = tmp / ".kube"
    workdir.mkdir(parents=True, exist_ok=True)
    kubeconfig_path = workdir / "config"

    parts = cluster.strip("/").split("/")
    subscription_id = parts[parts.index("subscriptions") + 1]
    resource_group = parts[parts.index("resourceGroups") + 1]
    cluster_name = parts[parts.index("managedClusters") + 1]

    client = ContainerServiceClient(_CREDENTIALS, subscription_id)
    response = client.managed_clusters.list_cluster_user_credentials(resource_group, cluster_name, format="exec")

    kubeconfig_content = yaml.safe_load(response.kubeconfigs[0].value)

    exec_config = kubeconfig_content["users"][0]["user"]["exec"]
    args = exec_config["args"]

    server_id = args[args.index("--server-id") + 1]

    kubeconfig_content["users"][0]["user"] = {"token": _CREDENTIALS.get_token(server_id).token}

    kubeconfig_path.write_text(yaml.safe_dump(kubeconfig_content, sort_keys=False), encoding="utf-8")
    os.environ["KUBECONFIG"] = str(kubeconfig_path)
    logger.info(f"KUBECONFIG: {kubeconfig_path}")
