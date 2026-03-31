FROM ghcr.io/gtsteffaniak/filebrowser:stable-slim AS filebrowser_quantum

FROM node:22-bookworm-slim AS openclaw_control_ui_builder

ARG OPENCLAW_VERSION=2026.3.24
ARG OPENCLAW_SOURCE_TAG=v2026.3.24

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/openclaw-src

RUN set -eux; \
  curl -fsSL "https://github.com/openclaw/openclaw/archive/refs/tags/${OPENCLAW_SOURCE_TAG}.tar.gz" | tar -xz --strip-components=1; \
  cd ui; \
  npm install; \
  npm run build

FROM node:22-bookworm-slim

ARG TTYD_VERSION=1.7.7
ARG HERMES_REF=v2026.3.12
ARG OPENCLAW_VERSION=2026.3.24

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    bubblewrap \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    ffmpeg \
    file \
    git \
    gnupg \
    htop \
    iptables \
    iputils-ping \
    jq \
    less \
    lsof \
    nano \
    netcat-openbsd \
    nginx \
    openssh-client \
    procps \
    python3 \
    python3-venv \
    ripgrep \
    sudo \
    tree \
    tmux \
    unzip \
    vim-tiny \
    zip \
  && mkdir -p /usr/share/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
  && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
    -o /etc/apt/sources.list.d/tailscale.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gh \
    tailscale \
  && mkdir -p /var/lib/tailscale /var/run/tailscale \
  && git --version \
  && gh --version \
  && bwrap --version \
  && test -x /usr/bin/bwrap \
  && tailscale version \
  && command -v tailscaled >/dev/null \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash linuxbrew \
  && mkdir -p /home/linuxbrew/.linuxbrew /home/linuxbrew/.cache/Homebrew \
  && chown -R linuxbrew:linuxbrew /home/linuxbrew

USER linuxbrew
RUN NONINTERACTIVE=1 CI=1 bash -lc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  && /home/linuxbrew/.linuxbrew/bin/brew --version

USER root

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "${arch}" in \
    amd64) ttyd_arch="x86_64" ;; \
    arm64) ttyd_arch="aarch64" ;; \
    *) echo "Unsupported architecture for ttyd: ${arch}" >&2; exit 1 ;; \
  esac; \
  curl -fsSL -o "/tmp/ttyd.${ttyd_arch}" "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"; \
  curl -fsSL -o /tmp/SHA256SUMS "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/SHA256SUMS"; \
  (cd /tmp && grep "  ttyd\\.${ttyd_arch}$" SHA256SUMS | sha256sum -c -); \
  install -m 0755 "/tmp/ttyd.${ttyd_arch}" /usr/local/bin/ttyd; \
  ttyd --version; \
  rm -f "/tmp/ttyd.${ttyd_arch}" /tmp/SHA256SUMS

COPY --from=openclaw_control_ui_builder /tmp/openclaw-src/dist/control-ui /opt/openclaw-control-ui-built

RUN npm install -g openclaw@${OPENCLAW_VERSION} @openai/codex@latest @anthropic-ai/claude-code@latest @google/gemini-cli@latest \
  && if ! command -v gemini >/dev/null 2>&1; then \
    gemini_fallback="$(find /usr/local/lib/node_modules/@google -maxdepth 3 -path '/usr/local/lib/node_modules/@google/.gemini-cli-*/dist/index.js' | head -n 1)"; \
    if [ -z "${gemini_fallback}" ]; then \
      echo "Gemini CLI install succeeded but no gemini executable was found." >&2; \
      exit 1; \
    fi; \
    ln -sf "${gemini_fallback}" /usr/local/bin/gemini; \
  fi \
  && rm -rf /usr/local/lib/node_modules/openclaw/dist/control-ui \
  && mkdir -p /usr/local/lib/node_modules/openclaw/dist/control-ui \
  && cp -a /opt/openclaw-control-ui-built/. /usr/local/lib/node_modules/openclaw/dist/control-ui/ \
  && mkdir -p /opt/openclaw-pristine \
  && cp -a /usr/local/lib/node_modules/openclaw /opt/openclaw-pristine/openclaw

RUN set -eux; \
  git clone --branch "${HERMES_REF}" --depth 1 --recurse-submodules --shallow-submodules https://github.com/NousResearch/hermes-agent.git /opt/hermes-src; \
  python3 -m venv /opt/hermes-venv; \
  /opt/hermes-venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel; \
  cd /opt/hermes-src; \
  /opt/hermes-venv/bin/pip install --no-cache-dir -e ".[cli,pty,mcp]"; \
  /opt/hermes-venv/bin/pip install --no-cache-dir -e "./mini-swe-agent"; \
  ln -sf /opt/hermes-venv/bin/hermes /usr/local/bin/hermes; \
  /opt/hermes-venv/bin/hermes version

WORKDIR /app

COPY --from=filebrowser_quantum /home/filebrowser /opt/filebrowser

COPY dashboard/package.json dashboard/package-lock.json /app/dashboard/
RUN cd /app/dashboard && npm install

COPY dashboard /app/dashboard
RUN cd /app/dashboard && npm run build

COPY entrypoint.sh launch_hermes_terminal.sh launch_codex_terminal.sh launch_claude_terminal.sh launch_gemini_terminal.sh bootstrap_skills.sh reset_openclaw_state.sh capture_openclaw_baseline.sh restart_openclaw_gateway.sh brew-wrapper.sh openclaw-wrapper.sh openclaw_runtime.js configure_filebrowser.js reconcile_filebrowser_permissions.js nginx.template.conf reconcile_openclaw_state.js print_reconcile_summary.js check_reconcile_status.js check_reconcile_status.sh approve_device.js dashboard_server.js ./
COPY lib /app/lib
RUN chmod +x /app/entrypoint.sh /app/launch_hermes_terminal.sh /app/launch_codex_terminal.sh /app/launch_claude_terminal.sh /app/launch_gemini_terminal.sh /app/bootstrap_skills.sh /app/reset_openclaw_state.sh /app/capture_openclaw_baseline.sh /app/restart_openclaw_gateway.sh /app/brew-wrapper.sh /app/openclaw-wrapper.sh /app/openclaw_runtime.js /app/print_reconcile_summary.js /app/check_reconcile_status.js /app/check_reconcile_status.sh /app/approve_device.js /app/dashboard_server.js \
  && ln -sf /app/approve_device.js /usr/local/bin/approve-device \
  && ln -sf /app/reset_openclaw_state.sh /usr/local/bin/reset-openclaw-state \
  && ln -sf /app/capture_openclaw_baseline.sh /usr/local/bin/capture-openclaw-baseline \
  && ln -sf /app/restart_openclaw_gateway.sh /usr/local/bin/restart-openclaw-gateway \
  && ln -sf /app/restart_openclaw_gateway.sh /usr/local/bin/restart-gateway \
  && ln -sf /app/brew-wrapper.sh /usr/local/bin/brew \
  && install -m 0755 /app/openclaw-wrapper.sh /usr/local/bin/openclaw \
  && mkdir -p /root/.codex /root/.claude /root/.gemini \
  && test -x /opt/filebrowser/filebrowser \
  && /opt/filebrowser/filebrowser version \
  && command -v hermes >/dev/null \
  && /usr/local/bin/brew --version \
  && codex --version \
  && claude --version \
  && command -v gemini >/dev/null \
  && npm list -g @google/gemini-cli --depth=0 >/dev/null

ENV PORT=8080
ENV OPENCLAW_INTERNAL_PORT=8081
ENV OPENCLAW_ACCESS_MODE=native
ENV OPENCLAW_GATEWAY_BIND=loopback
ENV OPENCLAW_EXPECTED_VERSION=${OPENCLAW_VERSION}
ENV OPENCLAW_RUNTIME_DIR=/usr/local/lib/node_modules/openclaw
ENV OPENCLAW_PRISTINE_DIR=/opt/openclaw-pristine/openclaw
ENV FILEBROWSER_INTERNAL_PORT=8082
ENV DASHBOARD_INTERNAL_PORT=8094
ENV DASHBOARD_BASE_URL=/dashboard
ENV DASHBOARD_API_BASE_URL=/dashboard-api
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV COLORTERM=truecolor
ENV OPENCLAW_TTY_TERM_PROGRAM=OpenClawTTYD
ENV TTYD_TERMINAL_TYPE=xterm-256color
ENV TTYD_CLIENT_RENDERER_TYPE=dom
ENV TTYD_CLIENT_FONT_FAMILY=ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace
ENV TTYD_CLIENT_FONT_SIZE=14
ENV TTYD_CLIENT_SCROLLBACK=50000
ENV OPENCLAW_STATE_DIR=/data/.openclaw
ENV OPENCLAW_WORKSPACE_DIR=/data/workspaces/openclaw
ENV OPENCLAW_CONFIG_PATH=/data/.openclaw/openclaw.json
ENV NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
ENV OPENCLAW_NO_RESPAWN=1
ENV FILEBROWSER_BASE_URL=/filebrowser
ENV FILEBROWSER_DATA_DIR=/data/.filebrowser
ENV FILEBROWSER_CONFIG_PATH=/tmp/filebrowser-config.yaml
ENV FILEBROWSER_DATABASE_PATH=/data/.filebrowser/database.db
ENV FILEBROWSER_CACHE_DIR=/data/.filebrowser/cache
ENV FILEBROWSER_USERNAME=operator
ENV HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
ENV HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
ENV HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
ENV HOMEBREW_RUN_AS_USER=linuxbrew
ENV PATH="/opt/hermes-venv/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HERMES_ENABLED=1
ENV HERMES_INTERNAL_PORT=8090
ENV HERMES_BASE_URL=/hermes
ENV HERMES_SESSION_NAME=hermes
ENV HERMES_HOME=/data/.hermes
ENV HERMES_WORKSPACE_DIR=/data/workspaces/hermes
ENV HERMES_OPENAI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
ENV HERMES_MODEL_NAME=gemini-3-flash-preview
ENV CODEX_ENABLED=1
ENV CODEX_INTERNAL_PORT=8091
ENV CODEX_BASE_URL=/codex
ENV CODEX_SESSION_NAME=codex
ENV CODEX_HOME=/data/.codex
ENV CODEX_WORKSPACE_DIR=/data/workspaces/codex
ENV CLAUDE_ENABLED=1
ENV CLAUDE_INTERNAL_PORT=8192
ENV CLAUDE_BASE_URL=/claude
ENV CLAUDE_SESSION_NAME=claude
ENV CLAUDE_HOME=/data/.claude
ENV CLAUDE_WORKSPACE_DIR=/data/workspaces/claude
ENV GEMINI_ENABLED=0
ENV GEMINI_INTERNAL_PORT=8093
ENV GEMINI_BASE_URL=/gemini
ENV GEMINI_SESSION_NAME=gemini
ENV GEMINI_HOME=/data/.gemini
ENV GEMINI_WORKSPACE_DIR=/data/workspaces/gemini
ENV TAILSCALE_STATE_DIR=/var/lib/tailscale
ENV TAILSCALE_RUN_DIR=/var/run/tailscale
ENV TAILSCALE_SOCKET=/var/run/tailscale/tailscaled.sock
ENV TAILSCALE_LOG_PATH=/var/log/tailscaled.log

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD bash -c 'test -s "${OPENCLAW_RECONCILE_SUMMARY_PATH:-/data/.openclaw/reconcile-summary.json}" && curl -fsS --max-time 5 "http://127.0.0.1:${PORT:-8080}/healthz" > /dev/null'

ENTRYPOINT ["/app/entrypoint.sh"]
