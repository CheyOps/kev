FROM python:3.13-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    UV_PYTHON=3.13 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_CACHE_DIR=/root/.cache/uv \
    UV_LINK_MODE=copy \
    HF_HOME=/cache/hf \
    TRITON_CACHE_DIR=/cache/hf/triton-cache

WORKDIR /app

# Install system deps (gcc: triton compiles its kernels at first use)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install kev dependencies
COPY pyproject.toml uv.lock README.md LICENSE ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --extra serve --no-install-project --python 3.13

# Install kev
COPY ./kev/ kev/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --extra serve --python 3.13 --inexact

# CUDA kernels go after the final sync: it would put the locked triton 3.4 back over the >=3.7.1 that fla needs
# Default 0 for CPU-only builds; compose.nvidia.yaml sets 1
ARG CUDA_KERNELS=0
RUN --mount=type=cache,target=/root/.cache/uv \
    if [ "$CUDA_KERNELS" = "1" ]; then \
      uv pip install --python /app/.venv/bin/python "flash-linear-attention==0.5.2" "triton>=3.7.1" && \
      uv pip install --python /app/.venv/bin/python --no-deps \
        "https://github.com/Dao-AILab/causal-conv1d/releases/download/v1.7.0/causal_conv1d-1.7.0%2Bcu12torch2.8cxx11abiTRUE-cp313-cp313-linux_x86_64.whl"; \
    fi

ENV PATH="/app/.venv/bin:$PATH"

# Serve it up!
CMD exec python -m kev.serve --run "$KEV_RUN" --port 8009 --host 0.0.0.0
EXPOSE 8009
