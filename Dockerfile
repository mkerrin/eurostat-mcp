# syntax=docker/dockerfile:1

# Eurostat MCP server.
# Built with uv against the committed uv.lock for reproducible installs.
# Runs over Streamable HTTP by default (good for containers); set
# MCP_TRANSPORT=stdio to fall back to stdio.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# uv settings: copy installed packages (not symlink) and don't try to
# manage/download a different Python than the image's.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app

# Install dependencies first (cached layer) using only the lockfile + manifest.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# Now copy the application source and install the project itself.
COPY server.py README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# Run as a non-root user.
RUN useradd --create-home --uid 10001 app
USER app

ENV PATH="/app/.venv/bin:$PATH"

# HTTP transport configuration. Bind to all interfaces inside the container so
# the published port is reachable; logs go to stderr, JSON-RPC over HTTP.
ENV MCP_TRANSPORT=streamable-http \
    MCP_HOST=0.0.0.0 \
    MCP_PORT=8002

EXPOSE 8002

ENTRYPOINT ["python", "server.py"]
