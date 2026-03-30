# Frontend Developer - Node.js Workspace

Coder workspace template for Frontend Developers with Node.js.

Docker image: `enricomeneghel/coder-fe-node`

## Architecture

- **Docker image** (`Dockerfile`) -- Base layer with all tools and runtimes pre-installed. Built and published automatically via GitHub Actions to Docker Hub on every push to main.
- **Coder template** (`main.tf`) -- Defines how the workspace is provisioned: container settings, volumes, IDE integrations, and startup behavior.

## Available IDEs

- VS Code Web (browser) -- optional, uses ~300-500MB RAM
- VS Code Desktop (requires Coder extension on client)

## Pre-installed Tools

- Node.js 24
- npm, yarn, pnpm
- TypeScript, ESLint, Prettier
- Vite
- Angular CLI, Vue CLI, Create React App, Nx

## VS Code Extensions

- ESLint
- Prettier
- Tailwind CSS IntelliSense
- GitLens
- Auto Rename Tag

## Parameters (selectable in Coder UI)

| Name | Description | Default |
|------|-------------|---------|
| resources | Resource size (small/medium/large/xlarge) | small |
| package_manager | Preferred package manager | npm |
| git_host | Git server hostname | github.com |
| git_pat | Personal Access Token for HTTPS authentication | - |
| git_repo_url | HTTPS URL of repo to clone on first start | - |
| enable_vscode_web | Enable VS Code Web | true |
| enable_docker | Mount Docker socket from host | false |

## Resources

| Size | CPU | RAM |
|------|-----|-----|
| medium | 2 | 8 GB |
| large | 3 | 12 GB |


## Docker-in-Workspace

Enabling the `enable_docker` parameter mounts the Docker socket from the host VM into the workspace. Containers started from within the workspace run as siblings on the host.

Before enabling, verify GID alignment between the host and the container:

    getent group docker

The Dockerfile uses `DOCKER_GID=987` by default. If the GID on your host differs, rebuild with:

    docker build --build-arg DOCKER_GID=<new_gid> .

## Usage

    # Create workspace
    coder create my-fe --template fe-node

    # With parameters
    coder create my-fe --template fe-node \
      --parameter resources=medium \
      --parameter package_manager=pnpm \
      --parameter git_repo_url=https://github.com/your-org/your-repo.git \
      --parameter git_pat=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

## Adding tools permanently

1. Fork or branch the repository
2. Edit the `Dockerfile`
3. Push to main -- GitHub Actions rebuilds and pushes the image automatically

## Persistence

The `/home/coder` directory is saved on a Docker volume and persists across workspace restarts.
