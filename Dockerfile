# Frontend Developer - Node.js Environment
# Base image only - startup logic is in the Coder template (main.tf)
ARG NODE_VERSION=24

FROM ubuntu:22.04

ARG NODE_VERSION
ARG CODE_SERVER_VERSION=4.96.4
ARG DOCKER_GID=987

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create coder user
RUN useradd -m -s /bin/bash -u 1000 coder

# Base packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    openssh-client \
    sudo \
    locales \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Node.js via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Yarn and pnpm
RUN npm install -g yarn pnpm

# Common frontend tools
RUN npm install -g \
    typescript \
    eslint \
    prettier \
    vite \
    @angular/cli \
    @vue/cli \
    create-react-app \
    nx

# code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}

# Passwordless sudo
RUN echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# Docker CLI + GID alignment with host VM docker group (GID 987)
# DOCKER_GID must match the GID of the docker group on the host VM.
# Verify with: getent group docker (on host VM)
# If the host GID changes, rebuild with: --build-arg DOCKER_GID=<new_gid>
RUN apt-get update && apt-get install -y docker.io \
    && rm -rf /var/lib/apt/lists/* \
    && groupmod -g ${DOCKER_GID} docker \
    && usermod -aG docker coder

# Directories
RUN mkdir -p /home/coder/projects && chown -R coder:coder /home/coder

# VS Code extensions
USER coder
RUN code-server --install-extension dbaeumer.vscode-eslint \
    && code-server --install-extension esbenp.prettier-vscode \
    && code-server --install-extension bradlc.vscode-tailwindcss \
    && code-server --install-extension eamodio.gitlens \
    && code-server --install-extension formulahendry.auto-rename-tag


# Pre-create coder binary placeholder so Docker bind mount works correctly
USER root
RUN touch /usr/bin/coder && chmod +x /usr/bin/coder

WORKDIR /home/coder
USER coder

CMD ["sleep", "infinity"]