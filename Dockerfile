## Multi-arch Jupyter + R (rsafd) environment
## Targets: linux/amd64 and linux/arm64 (works on Intel & Apple Silicon macOS, Linux, Windows WSL)
## Build example:
##   docker buildx build \
##     --platform linux/amd64,linux/arm64 \
##     -t ghcr.io/OWNER/rsafd-docker:latest \
##     --push .
## Replace OWNER with your GitHub org/user. Ensure you are logged in: echo $GHCR_PAT | docker login ghcr.io -u USERNAME --password-stdin

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC
ARG USERNAME=developer
ARG USERID=1000
ARG GROUPID=1000
ARG GH_OWNER="OWNER"

LABEL org.opencontainers.image.source="https://github.com/${GH_OWNER}/rsafd-docker" \
	  org.opencontainers.image.description="Multi-arch Jupyter (Python + R) with rsafd, tensorflow, keras, reticulate" \
	  org.opencontainers.image.licenses="MIT"

## Use bash for RUN
SHELL ["/bin/bash", "-c"]

## System packages (prioritize distro native binaries for arch-specific optimization)
RUN apt-get update -y && \
		apt-get install -y --no-install-recommends \
			gnupg ca-certificates curl wget git build-essential openssl \
			python3 python3-pip python3-venv python3-dev libpython3-dev \
			nodejs \
			r-base r-base-dev libcurl4-openssl-dev libssl-dev libxml2-dev \
			libopenblas-dev gfortran libpng-dev libjpeg-dev libfreetype6-dev pkg-config \
			libgl1-mesa-dev libglu1-mesa-dev libx11-dev libxext-dev libxrender-dev libxt-dev libxmu-dev libxi-dev \
			locales sudo tini libgmp-dev libglpk-dev && \
	locale-gen en_US.UTF-8 && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

## Create non-root user (matching host UID/GID optionally for mounted home)
RUN set -euo pipefail; \
	if getent group ${GROUPID} >/dev/null; then \
		EXISTING_GROUP_NAME=$(getent group ${GROUPID} | cut -d: -f1); \
		echo "GID ${GROUPID} already exists as ${EXISTING_GROUP_NAME}"; \
	else \
		groupadd -g ${GROUPID} ${USERNAME}; \
	fi; \
	TARGET_GROUP_NAME=$(getent group ${GROUPID} | cut -d: -f1); \
	if id -u ${USERID} >/dev/null 2>&1; then \
		echo "UID ${USERID} already exists, will re-use and ensure username ${USERNAME}"; \
		if ! id -u ${USERNAME} >/dev/null 2>&1; then \
			usermod -l ${USERNAME} $(getent passwd ${USERID} | cut -d: -f1) || true; \
			usermod -d /home/${USERNAME} -m ${USERNAME} || true; \
		fi; \
	elif id -u ${USERNAME} >/dev/null 2>&1; then \
		echo "User ${USERNAME} exists with different UID; not modifying UID"; \
	else \
		useradd -m -s /bin/bash -u ${USERID} -g ${TARGET_GROUP_NAME} ${USERNAME}; \
	fi; \
	usermod -aG sudo ${USERNAME} && echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nopasswd

WORKDIR /workspace

## Python virtual environment (PEP 668 friendly) and scientific stack
RUN python3 -m venv /opt/venv && \
	/opt/venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel && \
	/opt/venv/bin/pip install --no-cache-dir \
		notebook jupyterlab ipykernel \
		numpy pandas scipy matplotlib seaborn scikit-learn \
		tensorflow keras && \
	/opt/venv/bin/python -m ipykernel install --name python3 --display-name "Python 3 (venv)" --sys-prefix

## Environment variables for reticulate to find venv python
ENV PATH="/opt/venv/bin:$PATH" \
    RETICULATE_PYTHON=/opt/venv/bin/python

## R package installation (IRkernel for Jupyter, reticulate bridge, Rsafd copied from repo)
RUN R -q -e "install.packages(c('IRkernel','remotes','reticulate'), repos='https://cloud.r-project.org', dependencies=TRUE)" && \
	R -q -e "install.packages('RcppEigen', repos='https://cloud.r-project.org', dependencies=TRUE)" && \
	R -q -e "install.packages('igraph', repos='https://cloud.r-project.org', dependencies=TRUE)" && \
	R -q -e "install.packages(c('timeDate','quadprog','quantreg','plot3D','robustbase','scatterplot3d','tseries','glasso','qgraph','keras','rgl','glmnet'), repos='https://cloud.r-project.org', dependencies=TRUE)" && \
	R -q -e "IRkernel::installspec(user = FALSE, name='ir', displayname='R')" && \
	git clone --depth=1 https://github.com/princetonuniversity/rsafd /usr/local/lib/R/site-library/Rsafd && \
	rm -rf /usr/local/lib/R/site-library/Rsafd/.git && \
	R -q -e "library(Rsafd); cat('Rsafd loaded (copied)\n')"

## (Optional) Basic import tests to fail early if something is broken
RUN /opt/venv/bin/python - <<'PYTEST' && \
	R -q -e 'library(Rsafd); cat("Rsafd loaded successfully (smoke test)\n")' && \
	R -q -e 'library(reticulate); tf <- import("tensorflow"); cat(tf[["__version__"]], "\n")'
import tensorflow as tf
import keras
print('TensorFlow:', tf.__version__)
print('Keras:', keras.__version__)
PYTEST

## Expose Jupyter default port
EXPOSE 8888

## Make sure notebooks & data written with correct ownership when running as non-root
RUN mkdir -p /workspace/notebooks && chown -R ${USERNAME}:${GROUPID} /workspace

COPY start-jupyter.sh /usr/local/bin/start-jupyter
RUN chmod +x /usr/local/bin/start-jupyter

# Copy healthcheck script
COPY healthcheck.sh /usr/local/bin/healthcheck
RUN chmod +x /usr/local/bin/healthcheck

USER ${USERNAME}
ENV HOME=/home/${USERNAME}

ENV JUPYTER_PORT=8888 \
	JUPYTER_DISABLE_TOKEN=0 \
	JUPYTER_TOKEN="" \
	JUPYTER_LAB_ARGS="" \
	JUPYTER_PLAIN_URL=0 \
	JUPYTER_DISABLE_LSP=1 \
	JUPYTER_LINK_ONLY=0 \
	JUPYTER_UI=notebook

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/start-jupyter"]

HEALTHCHECK --interval=2m --timeout=20s --start-period=30s --retries=3 CMD /usr/local/bin/healthcheck || exit 1

