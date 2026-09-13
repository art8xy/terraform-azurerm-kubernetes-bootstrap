import os
import logging
import tempfile
import json
import kube
import helm

from pathlib import Path

import azure.functions as func

logger = logging.getLogger()
logger.setLevel(logging.INFO)

app = func.FunctionApp()
@app.function_name(name="handler")
@app.route(route="handler", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def handler(req: func.HttpRequest) -> func.HttpResponse:
    logger.info(f"Received request: {req}")

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)

            cluster = os.environ["CLUSTER"]
            kube.config(tmp, cluster)

            data = req.get_json() or {}
            charts = data["charts"]
            for name, chart in charts.items():
                logger.info(f"Installing {name} chart")
                helm.install(tmp, helm.Chart(
                    release=name,
                    chart=chart["chart"],
                    repository=chart["repository"],
                    version=chart["version"],
                    namespace=chart["namespace"],
                    values=chart.get("values", {}),
                    wait=chart["wait"],
                    timeout=chart["timeout"],
                    create_namespace=chart["create_namespace"],
                ))
                logger.info(f"Chart {name} installed successfully")

    except Exception as e:
        logger.error(f"Provisioning failed: {e}")
        return func.HttpResponse(body=json.dumps({"status": "Provisioning failed", "error": str(e)}), status_code=500, mimetype="application/json")

    return func.HttpResponse(body=json.dumps({"status": "Provisioning successful"}), status_code=200, mimetype="application/json")
