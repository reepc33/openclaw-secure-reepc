# OpenClaw Secure - Docker Support

This directory contains Docker configuration for running OpenClaw in an isolated environment.

## Quick Start

```bash
cd docker
docker-compose up -d
```

## Files

- `Dockerfile` - OpenClaw container image
- `docker-compose.yml` - Multi-container setup
- `entrypoint.sh` - Container startup script

## Security Benefits

Running OpenClaw in Docker provides:

1. **Process Isolation** - OpenClaw runs in its own container
2. **Network Isolation** - Only exposed ports are accessible
3. **Filesystem Isolation** - Limited access to host filesystem
4. **Resource Limits** - CPU and memory constraints

## Configuration

Edit `docker-compose.yml` to customize:

```yaml
environment:
  - OPENCLAW_TOKEN=your-secure-token
  - OPENCLAW_PORT=18789
volumes:
  - ./workspace:/home/openclaw/.openclaw/workspace
```

## Building

```bash
docker build -t openclaw-secure .
```

## Notes

- Token is passed via environment variable (more secure than config file)
- Workspace is persisted in a Docker volume
- Container runs as non-root user
