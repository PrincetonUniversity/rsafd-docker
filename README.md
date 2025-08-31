# Rsafd-Docker 

Multi-architecture (linux/amd64 + linux/arm64) Jupyter environment with both Python and R kernels and the [Rsafd](https://github.com/princetonuniversity/rsafd) R package pre-installed.

Includes:
* R, Rsafd, IRkernel, reticulate
* Python, TensorFlow, Keras, and scientific stack (numpy, pandas, scipy, scikit-learn, matplotlib, seaborn)
* The reticulate package configured with Python virtualenv
* Healthcheck that validates TensorFlow + Rsafd + reticulate bridge

## Quick Start

```
docker run -p 8888:8888 -e JUPYTER_LINK_ONLY=1 -v "$HOME":/workspace/notebooks ghcr.io/princetonuniversity/rsafd-docker:latest
```

Open the printed URL in a browser to access Jupyter.

## Feature Matrix

| Capability | Details |
|------------|---------|
| Auth token | Random secure token by default (can disable) |
| UI modes | Switch between JupyterLab or classic Notebook via `JUPYTER_UI` |
| Quiet modes | Single-line plain or link-only output for scripting |
| Rsafd install | Direct repo clone into site library (non-CRAN) |
| Healthcheck | `/usr/local/bin/healthcheck` (wired into Docker HEALTHCHECK) |
| CI Workflow | `.github/workflows/docker-multi-arch.yml` pushes multi-tag images to GHCR |

### Container Options (Lab vs Notebook)

```
# Classic Notebook (default)
docker run -p 8888:8888 -e JUPYTER_UI=notebook -e JUPYTER_LINK_ONLY=1 -v "$HOME":/workspace/notebooks ghcr.io/princetonuniversity/rsafd-docker:latest

# JupyterLab
docker run -p 8888:8888 -e JUPYTER_UI=lab -e JUPYTER_LINK_ONLY=1 -v "$HOME":/workspace/notebooks ghcr.io/princetonuniversity/rsafd-docker:latest
```

### Token Control

| Scenario | Setting |
|----------|---------|
| Random secure (default) | no vars needed |
| Provide explicit | `-e JUPYTER_TOKEN=yourtoken` |
| Disable (INSECURE) | `-e JUPYTER_DISABLE_TOKEN=1` |

When disabled, anyone with port access can use the server—only for trusted local use.  Proceed with caution.

### Healthcheck

Docker HEALTHCHECK runs `/usr/local/bin/healthcheck` every 2 minutes (after a 30s start period) ensuring:
1. Python TensorFlow imports
2. R can load Rsafd
3. reticulate sees TensorFlow

### Build Locally (Multi-Arch)

```bash
IMAGE=ghcr.io/princetonniversity/rsafd-docker:latest
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
