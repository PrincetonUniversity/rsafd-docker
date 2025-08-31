# Rsafd-Docker 

Multi-architecture (linux/amd64 + linux/arm64) Jupyter environment with both Python and R kernels and the [Rsafd](https://github.com/princetonuniversity/rsafd) R package pre-installed.

* R, Rsafd, IRkernel, reticulate
* Python, TensorFlow, Keras, and a common scientific stack (numpy, pandas, scipy, scikit-learn, matplotlib, seaborn)
* Reticulate configured with Python virtualenv, healthcheck that validates TensorFlow + Rsafd + reticulate bridge

## Quick Start

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Run the container by pasting the relevant command into the Terminal within the Docker Desktop app.
	- macOS/Linux
		```
		docker run -p 8888:8888 -e JUPYTER_LINK_ONLY=1 -v "$HOME":/workspace/notebooks ghcr.io/princetonuniversity/rsafd-docker:latest
		```
	- Windows
		```
		docker run -p 8888:8888 -e JUPYTER_LINK_ONLY=1 -v "${env:USERPROFILE}:/workspace/notebooks" ghcr.io/princetonuniversity/rsafd-docker:latest
		```

3. Open the printed URL in a browser to access Jupyter and work with notebooks.

## Features

| Capability | Details |
|------------|---------|
| UI modes | Switch between JupyterLab or classic Notebook via `-e JUPYTER_UI=notebook` or `-e JUPYTER_UI=lab` |
| Healthcheck | `/usr/local/bin/healthcheck` (wired into Docker HEALTHCHECK) |
| Token control | Defaults to random, options to set a reusable token via `-e JUPYTER_TOKEN=yourtoken` or disable via `-e JUPYTER_DISABLE_TOKEN=1`|

## Development 

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
