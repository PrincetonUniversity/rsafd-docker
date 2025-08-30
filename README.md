# Rsafd-Docker

Multi-architecture (linux/amd64 + linux/arm64) Jupyter environment with both Python and R kernels and the `Rsafd` R package pre-installed.

Includes:
* R: rsafd (GitHub clone), IRkernel, reticulate + supporting deps
* Python: TensorFlow, Keras, scientific stack (numpy, pandas, scipy, scikit-learn, matplotlib, seaborn)
* Interop: reticulate wired to the Python virtualenv
* Healthcheck: validates TensorFlow + Rsafd + reticulate bridge

## Feature Matrix

| Capability | Details |
|------------|---------|
| Auth token | Random secure token by default (can disable) |
| UI modes | Switch between JupyterLab or classic Notebook via `JUPYTER_UI` |
| Quiet modes | Single-line plain or link-only output for scripting |
| Rsafd install | Direct repo clone into site library (non-CRAN) |
| Healthcheck | `/usr/local/bin/healthcheck` (wired into Docker HEALTHCHECK) |
| CI Workflow | `.github/workflows/docker-multi-arch.yml` pushes multi-tag images to GHCR |

## Quick Start

```bash
IMAGE=ghcr.io/OWNER/rsafd-docker:latest   # replace OWNER
docker run -p 8888:8888 $IMAGE
# Terminal prints: OPEN THIS URL: http://127.0.0.1:8888/lab?token=....
```

Open the printed URL in a browser; both Python and R kernels appear.

### Student Usage (Pull & Run)

Give students only these two commands (replace OWNER beforehand):

```bash
docker pull ghcr.io/OWNER/rsafd-docker:latest
docker run -p 8888:8888 ghcr.io/OWNER/rsafd-docker:latest
```

They copy the printed OPEN THIS URL line into a browser. Architecture (Intel vs Apple Silicon) is chosen automatically by Docker.

Pin to a stable build (date tag example):
```bash
docker pull ghcr.io/OWNER/rsafd-docker:20250827
```

If the image is private, instruct them to authenticate first (PAT with `read:packages`):
```bash
echo "$GITHUB_PAT" | docker login ghcr.io -u GITHUB_USERNAME --password-stdin
```

### Choose UI (Lab vs Notebook)

```bash
# Classic Notebook (default)
docker run -p 8888:8888 -e JUPYTER_UI=notebook $IMAGE

# JupyterLab
docker run -p 8888:8888 -e JUPYTER_UI=lab $IMAGE
```

### Output Modes

| Mode | Variables | Output |
|------|-----------|--------|
| Full banner | (default) | Colored banner + two URLs |
| Link only (colored) | `JUPYTER_LINK_ONLY=1` | One colored OPEN THIS URL line, silent server logs |
| Plain single line | `JUPYTER_PLAIN_URL=1` | Bare URL (good for scripts / copy) |

### Token Control

| Scenario | Setting |
|----------|---------|
| Random secure (default) | no vars needed |
| Provide explicit | `-e JUPYTER_TOKEN=yourtoken` |
| Disable (INSECURE) | `-e JUPYTER_DISABLE_TOKEN=1` |

When disabled, anyone with port access can use the server—only for trusted local use.

### Mount Data / Notebooks

```bash
docker run --rm -p 8888:8888 \
	-v "$PWD":/workspace/notebooks \
	-v "$HOME":/home/developer/hosthome \
	$IMAGE
```

### Environment Variable Summary

| Var | Default | Purpose |
|-----|---------|---------|
| JUPYTER_PORT | 8888 | Server port |
| JUPYTER_UI | lab | 'lab' or 'notebook' UI |
| JUPYTER_TOKEN | (blank -> random) | Explicit token override |
| JUPYTER_DISABLE_TOKEN | 0 | Set 1 to disable auth token (insecure) |
| JUPYTER_PLAIN_URL | 0 | Print only plain URL (keep logs) |
| JUPYTER_LINK_ONLY | 0 | Print one colored URL line and silence logs |
| JUPYTER_LAB_ARGS | (empty) | Extra args appended to server command |
| JUPYTER_DISABLE_LSP | 1 | Attempt to disable LSP noise |

### Healthcheck

Docker HEALTHCHECK runs `/usr/local/bin/healthcheck` every 2 minutes (after a 30s start period) ensuring:
1. Python TensorFlow imports
2. R can load Rsafd
3. reticulate sees TensorFlow

Manual run inside container:
```bash
/usr/local/bin/healthcheck
```

Container status turns `unhealthy` if these fail (view with `docker inspect` or `docker ps`).

### Build Locally (Multi-Arch)

```bash
IMAGE=ghcr.io/OWNER/rsafd-docker:latest
docker buildx create --name rsafd-builder --use 2>/dev/null || true
docker buildx inspect --bootstrap
docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGE --push .
```

### GitHub Actions Workflow

`.github/workflows/docker-multi-arch.yml` auto-builds on pushes to `main` and manual dispatch. Tags produced:
* `latest`
* Date stamp (`YYYYMMDD`)
* Short SHA (12 chars)
* Optional manual input tag

### Runtime Smoke Tests

Python:
```python
import tensorflow as tf, keras
print(tf.__version__)
```

R:
```r
library(Rsafd)
library(reticulate)
py <- import('tensorflow')
py$`__version__`
```

### Extending

Add R packages (example):
```dockerfile
RUN R -q -e "install.packages('xts', repos='https://cloud.r-project.org', dependencies=TRUE)"
```

Add Python packages:
```dockerfile
RUN /opt/venv/bin/pip install --no-cache-dir xgboost
```

### Notes

* Rsafd is cloned directly (non-CRAN); updates require rebuilding.
