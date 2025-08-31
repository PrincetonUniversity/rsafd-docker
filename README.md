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
| Persistent user installs | Python & R packages installed in the notebook via `!pip install` / `install.packages()` persist in mounted volume |

## Persistent Package Installs 

When you mount a host directory to `/workspace/notebooks`, the container creates a per-image hash directory that keeps any packages you install interactively:

```
/workspace/notebooks/.rsafd-docker-<image-sha>/
	py/   # Python user packages (PIP_TARGET)
	R/    # R user library (R_LIBS_USER)
```

The image SHA is the short Git commit hash baked into the image (keeps environments separate across different pulls). Environment variables set automatically:

* `PIP_TARGET` + `PYTHONPATH` → Python installs go to `py/`
* `R_LIBS_USER` → R installs go to `R/`

Usage examples inside a notebook cell:

Python:
```python
!pip install statsmodels
import statsmodels.api as sm
```

R:
```r
install.packages("xts")
library(xts)
```

After container restart (with the same host volume mounted), those packages remain available. To inspect what’s been added:
```bash
ls /workspace/notebooks/.rsafd-docker-*/py
ls /workspace/notebooks/.rsafd-docker-*/R
```

To “reset” just remove the directory on the host:
```bash
rm -rf /path/on/host/.rsafd-docker-*/
```

## Development 

### Extending

Add R packages (example):
```dockerfile
RUN R -q -e "install.packages('xts', repos='https://cloud.r-project.org', dependencies=TRUE)"
```

Add Python packages:
```dockerfile
RUN /opt/venv/bin/pip install --no-cache-dir xgboost
```

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `exec -v failed` | Placed `-v` flag after image name | Put `-v` before the image reference |
| Package gone after restart | Volume not mounted or different mount path | Ensure `-v hostdir:/workspace/notebooks` is present |
| Python cannot see newly installed pkg | Notebook kernel not restarted | Restart the kernel after `!pip install` |
| R install asks for a CRAN mirror | Non-interactive mirror missing | Add `repos='https://cloud.r-project.org'` in `install.packages()` |

### Healthcheck

Docker HEALTHCHECK runs `/usr/local/bin/healthcheck` every 2 minutes (after a 30s start period) ensuring:
1. Python TensorFlow imports
2. R can load Rsafd
3. reticulate sees TensorFlow

### Multi-Arch Local Build

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
