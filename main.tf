# =============================================================================
# FRONTEND DEVELOPER - NODE.JS WORKSPACE
# =============================================================================

terraform {
  required_providers {
    coder  = { source = "coder/coder" }
    docker = { source = "kreuzwerker/docker" }
  }
}

provider "coder" {}
provider "docker" {}

# =============================================================================
# INFRASTRUCTURE VARIABLES (not shown in UI)
# =============================================================================

variable "docker_registry" {
  description = "Docker registry where the workspace image is hosted"
  type        = string
  default     = "enricomeneghel"
}

variable "coder_url" {
  description = "Public URL of the Coder server"
  type        = string
  default     = "http://4.212.240.110"
}

variable "coder_binary_host_path" {
  description = "Path to the coder binary on the worker host"
  type        = string
  default     = "/usr/local/bin/coder"
}

# =============================================================================
# USER PARAMETERS (shown in Coder UI)
# =============================================================================

data "coder_parameter" "resources" {
  name         = "resources"
  display_name = "Resource Size"
  description  = "CPU and memory allocation for the workspace"
  type         = "string"
  default      = "medium"
  mutable      = true
  icon         = "/icon/memory.svg"

  option {
    name  = "Medium (2 CPU, 8GB RAM)"
    value = "medium"
  }
  option {
    name  = "Large (3 CPU, 12GB RAM)"
    value = "large"
  }
}

data "coder_parameter" "package_manager" {
  name         = "package_manager"
  display_name = "Package Manager"
  description  = "Preferred Node.js package manager"
  type         = "string"
  default      = "npm"
  mutable      = true
  icon         = "/icon/nodejs.svg"

  option {
    name  = "npm"
    value = "npm"
  }
  option {
    name  = "yarn"
    value = "yarn"
  }
  option {
    name  = "pnpm"
    value = "pnpm"
  }
}

data "coder_parameter" "git_host" {
  name         = "git_host"
  display_name = "Git Host"
  description  = "Hostname of the Git server (e.g. github.com, gitlab.com)"
  type         = "string"
  default      = "github.com"
  mutable      = true
  icon         = "/icon/git.svg"
}

data "coder_parameter" "git_pat" {
  name         = "git_pat"
  display_name = "Git Personal Access Token"
  description  = "PAT for HTTPS Git authentication. Leave empty for public repositories."
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/git.svg"
}

data "coder_parameter" "git_repo_url" {
  name         = "git_repo_url"
  display_name = "Git Repository URL"
  description  = "HTTPS URL of the repository to clone on first start (leave empty to skip)"
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/git.svg"
}

data "coder_parameter" "enable_vscode_web" {
  name         = "enable_vscode_web"
  display_name = "Enable VS Code Web"
  description  = "Enable browser-based VS Code (uses ~300-500MB RAM)"
  type         = "bool"
  default      = "true"
  mutable      = true
  icon         = "/icon/code.svg"
}

data "coder_parameter" "enable_docker" {
  name         = "enable_docker"
  display_name = "Enable Docker-in-Workspace"
  description  = "Mount Docker socket from host. Enables Docker builds and Testcontainers. Requires docker group GID alignment between host and container."
  type         = "bool"
  default      = "false"
  mutable      = true
  icon         = "/icon/docker.svg"
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  resource_map = {
    small  = { cpu = 2, memory = 4096 }
    medium = { cpu = 2, memory = 8192 }
    large  = { cpu = 3, memory = 12288 }
    xlarge = { cpu = 4, memory = 16384 }
  }
  cpu    = local.resource_map[data.coder_parameter.resources.value].cpu
  memory = local.resource_map[data.coder_parameter.resources.value].memory
}

# =============================================================================
# DATA
# =============================================================================

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# =============================================================================
# AGENT
# =============================================================================

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder/projects"

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true
  }

  startup_script_behavior = "non-blocking"
  startup_script = <<-EOT
    #!/bin/bash

    %{if data.coder_parameter.enable_vscode_web.value == "true"}
    echo "Starting code-server..."
    /usr/bin/code-server \
      --auth none \
      --bind-addr 0.0.0.0:8080 \
      /home/coder/projects > /tmp/code-server.log 2>&1 &
    %{endif}

    %{if data.coder_parameter.package_manager.value == "yarn"}
    if ! command -v yarn &>/dev/null; then
      echo "Installing yarn..."
      npm install -g yarn > /tmp/pkg-manager-install.log 2>&1 || echo "[WARN] yarn install failed"
    fi
    %{endif}
    %{if data.coder_parameter.package_manager.value == "pnpm"}
    if ! command -v pnpm &>/dev/null; then
      echo "Installing pnpm..."
      npm install -g pnpm > /tmp/pkg-manager-install.log 2>&1 || echo "[WARN] pnpm install failed"
    fi
    %{endif}
  EOT

  metadata {
    display_name = "CPU"
    key          = "cpu"
    script       = "cat /proc/stat | awk 'NR==1{usage=($2+$4)*100/($2+$4+$5); printf \"%.1f%%\", usage}'"
    interval     = 10
    timeout      = 3
  }

  metadata {
    display_name = "RAM"
    key          = "mem"
    script       = "free -m | awk 'NR==2{printf \"%.0f%%\", $3*100/$2}'"
    interval     = 10
    timeout      = 3
  }

  metadata {
    display_name = "Node"
    key          = "node"
    script       = "node --version 2>/dev/null || echo 'not found'"
    interval     = 600
    timeout      = 3
  }
}

# =============================================================================
# APPS
# =============================================================================

resource "coder_app" "vscode_web" {
  count        = data.coder_parameter.enable_vscode_web.value == "true" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "vscode-web"
  display_name = "VS Code Web"
  url          = "http://localhost:8080?folder=/home/coder/projects"
  icon         = "/icon/code.svg"
  share        = "owner"
  subdomain    = false

  healthcheck {
    url       = "http://localhost:8080/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "vscode_desktop" {
  agent_id     = coder_agent.main.id
  slug         = "vscode-desktop"
  display_name = "VS Code Desktop"
  url          = "vscode://coder.coder-remote/open?owner=${data.coder_workspace_owner.me.name}&workspace=${data.coder_workspace.me.name}&url=${var.coder_url}&folder=/home/coder/projects"
  icon         = "/icon/code.svg"
  external     = true
}

# =============================================================================
# DOCKER
# =============================================================================

resource "docker_image" "workspace" {
  name         = "${var.docker_registry}/coder-fe-node:latest"
  keep_locally = true
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

resource "docker_container" "workspace" {
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image = docker_image.workspace.image_id

  cpu_shares = local.cpu * 1024
  memory     = local.memory

  volumes {
    volume_name    = docker_volume.home.name
    container_path = "/home/coder"
  }

  volumes {
    host_path      = var.coder_binary_host_path
    container_path = "/usr/local/bin/coder"
    read_only      = true
  }

  dynamic "volumes" {
    for_each = data.coder_parameter.enable_docker.value == "true" ? [1] : []
    content {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
    }
  }

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_URL=${var.coder_url}",
  ]

  entrypoint = ["/bin/bash", "-c"]
  command = [<<-EOT
mkdir -p /home/coder/projects

%{if data.coder_parameter.git_pat.value != ""}
git config --global credential.helper 'store --file=/tmp/.git-credentials'
echo "https://oauth2:${data.coder_parameter.git_pat.value}@${data.coder_parameter.git_host.value}" > /tmp/.git-credentials
chmod 600 /tmp/.git-credentials
%{endif}

git config --global user.email "${data.coder_workspace_owner.me.email}"
git config --global user.name "${data.coder_workspace_owner.me.full_name != "" ? data.coder_workspace_owner.me.full_name : data.coder_workspace_owner.me.name}"

%{if data.coder_parameter.git_repo_url.value != ""}
REPO_NAME=$(basename "${data.coder_parameter.git_repo_url.value}" .git)
if [ ! -d "/home/coder/projects/$REPO_NAME" ]; then
  cd /home/coder/projects
  git clone "${data.coder_parameter.git_repo_url.value}" "$REPO_NAME" 2>&1 || \
    echo "[WARN] Git clone failed - check URL and credentials"
fi
%{endif}

echo "[INFO] CODER_AGENT_URL=$CODER_AGENT_URL"
curl -sS --max-time 5 "$CODER_AGENT_URL/api/v2/buildinfo" && echo "" || echo "[WARN] Cannot reach Coder server"
exec /usr/local/bin/coder agent
EOT
  ]

  restart  = "unless-stopped"
  hostname = "fe-${data.coder_workspace.me.name}"
}
