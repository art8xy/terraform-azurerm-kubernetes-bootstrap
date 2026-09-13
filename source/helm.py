import os
import yaml
import logging
import subprocess

from pathlib import Path
from dataclasses import dataclass

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ROOT = Path(__file__).resolve().parent

@dataclass
class Chart:
    release: str
    chart: str
    repository: str | None
    version: str | None
    namespace: str
    values: dict
    wait: bool
    timeout: str
    create_namespace: bool

def install(tmp: Path, chart: Chart) -> None:
    helm = _binary()
    env = _env(tmp)
    cmd = [str(helm), "upgrade", "--install", chart.release, chart.chart]

    if chart.repository:
        cmd.extend(["--repo", chart.repository])

    if chart.version:
        cmd.extend(["--version", chart.version])

    if chart.values:
        values_file = tmp / f"{chart.release}-values.yaml"
        values_file.write_text(yaml.safe_dump(chart.values, sort_keys=False), encoding="utf-8")
        cmd.extend(["--values", str(values_file)])

    if chart.namespace:
        cmd.extend(["--namespace", chart.namespace])

    if chart.wait:
        cmd.append("--wait")

    if chart.timeout:
        cmd.extend(["--timeout", chart.timeout])
    
    if chart.create_namespace:
        cmd.append("--create-namespace")

    _run(cmd, env)

def _binary() -> Path:
    helm = ROOT / "bin" / "helm"
    if not helm.exists():
        raise FileNotFoundError(f"Helm binary not found at {helm}")
    return helm

def _env(tmp: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["HELM_CACHE_HOME"] = str(tmp)
    env["HELM_CONFIG_HOME"] = str(tmp)
    env["HELM_DATA_HOME"] = str(tmp)
    return env

def _run(cmd: list[str], env: dict[str, str]) -> None:
    logger.info(f"Running command: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, env=env, text=True, capture_output=True, check=True)
    except subprocess.CalledProcessError as e:
        logger.error("stdout:\n%s", e.stdout)
        logger.error("stderr:\n%s", e.stderr)
        raise
    logger.info(result.stdout)
