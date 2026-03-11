# NubiferOS Cloud Tools Container
# Provides the NubiferOS CLI toolchain for CI/CD pipelines and evaluation
#
# Usage:
#   docker run -it ghcr.io/nubiferos/nubifer-tools
#   docker run -it ghcr.io/nubiferos/nubifer-tools nubiferai front "list my EC2 instances"
#
# With credentials:
#   docker run -it -v ~/.aws:/root/.aws ghcr.io/nubiferos/nubifer-tools
#   docker run -it -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY ghcr.io/nubiferos/nubifer-tools

# Stage 1: Clone NubiferAI source (cached separately)
FROM debian:bookworm-slim AS nubiferai-src
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --branch trunk --depth 1 https://github.com/nubiferos/nubiferai.git /src

# Stage 2: Final image
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="NubiferOS Cloud Tools"
LABEL org.opencontainers.image.description="AI-native multi-cloud management toolkit"
LABEL org.opencontainers.image.source="https://github.com/nubiferos/nubiferos"
LABEL org.opencontainers.image.url="https://nubiferos.org"
LABEL org.opencontainers.image.vendor="NubiferOS Project"

ARG NUBIFEROS_VERSION=0.1.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    NUBIFEROS_CONTAINER=true

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    pass \
    python3 \
    python3-pip \
    python3-venv \
    python3-keyring \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Cloud CLIs
# ============================================

# AWS CLI v2
RUN curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscli.zip

# Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && rm -rf /var/lib/apt/lists/*

# Google Cloud CLI
RUN curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# IaC & Container Tools
# ============================================

# Terraform
RUN curl -sL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com bookworm main" \
       > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# kubectl
RUN curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Helm
RUN curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ============================================
# NubiferOS Components
# ============================================

# Credential manager
COPY components/credential-manager/nubifer-creds /usr/local/bin/nubifer-creds
COPY components/credential-manager/nubifer-aws-credential-helper /usr/local/bin/nubifer-aws-credential-helper

# Workspace manager
COPY components/workspace-manager/nubifer-workspace /usr/local/bin/nubifer-workspace
COPY components/workspace-manager/shell-integration.sh /etc/nubifer/shell-integration.sh

# CLI wrappers (read-only mode enforcement)
COPY components/workspace-manager/cli-wrappers/ /usr/local/lib/nubifer/cli-wrappers/

# Audit trail
COPY components/audit-trail/audit-functions.sh /etc/nubifer/audit-functions.sh
COPY components/audit-trail/schema.sql /etc/nubifer/audit-schema.sql
COPY components/audit-trail/nubifer-audit /usr/local/bin/nubifer-audit

RUN chmod +x /usr/local/bin/nubifer-* \
    && chmod +x /usr/local/lib/nubifer/cli-wrappers/*

# Symlink wrappers to intercept CLI commands
RUN for wrapper in /usr/local/lib/nubifer/cli-wrappers/*; do \
      name=$(basename "$wrapper"); \
      real_bin=""; \
      for dir in /usr/bin /usr/local/bin /snap/bin; do \
        if [ -x "$dir/$name" ] && [ "$dir/$name" != "$wrapper" ]; then \
          real_bin="$dir/$name"; break; \
        fi; \
      done; \
      if [ -n "$real_bin" ]; then \
        ln -sf "$wrapper" "/usr/local/bin/$name"; \
      fi; \
    done

# NubiferOS config
RUN mkdir -p /etc/nubiferos /usr/share/nubifer
COPY configs/nubiferos/nubiferos.conf /etc/nubiferos/nubiferos.conf
COPY scripts/tools-config.yaml /usr/share/nubifer/tools-config.yaml

# ============================================
# NubiferAI
# ============================================

COPY --from=nubiferai-src /src/packages/nubiferai-core /tmp/nubiferai-core
COPY --from=nubiferai-src /src/packages/nubiferai-cli /tmp/nubiferai-cli
COPY --from=nubiferai-src /src/seeds /etc/nubiferai/seeds/

RUN python3 -m venv --system-site-packages /opt/nubiferos/addons/nubiferai/.venv \
    && /opt/nubiferos/addons/nubiferai/.venv/bin/pip install --no-cache-dir --quiet \
       /tmp/nubiferai-core /tmp/nubiferai-cli \
    && ln -sf /opt/nubiferos/addons/nubiferai/.venv/bin/nubiferai /usr/local/bin/nubiferai \
    && rm -rf /tmp/nubiferai-core /tmp/nubiferai-cli

# Default NubiferAI config
RUN mkdir -p /etc/nubiferai && cat > /etc/nubiferai/config.toml << 'EOF'
[ai]
enabled = false
provider = "none"

[ai.security]
require_approval_for_writes = true
log_all_queries = true
filter_sensitive_data = true

[ai.privacy]
anonymize_account_ids = true
EOF

# ============================================
# Shell integration & cleanup
# ============================================

RUN cat >> /etc/bash.bashrc << 'SHELL'

# NubiferOS Shell Integration
if [ -f /etc/nubifer/shell-integration.sh ]; then
    source /etc/nubifer/shell-integration.sh
fi

# Container indicator
export PS1='\[\e[36m\][nubifer-tools]\[\e[0m\] \u@\h:\w\$ '
SHELL

# Version info
RUN echo "NubiferOS Cloud Tools ${NUBIFEROS_VERSION}" > /etc/nubiferos-container-version

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

WORKDIR /workspace
CMD ["/bin/bash"]
