# n8n Workflows

This directory contains version-controlled JSON exports of our n8n workflows for the AI Sales Agent.

## Exporting Workflows

Workflows can be exported either via the n8n UI or via the CLI in the running Docker container:

### Using the backup script:
```powershell
./scripts/backup.ps1
```
or on Linux:
```bash
./scripts/backup.sh
```

### Manual CLI export:
```bash
docker compose exec -u node n8n n8n export:workflow --all --output=/home/node/.n8n/workflows/
```

## Importing Workflows

To import all workflows from this directory into the n8n container:
```bash
docker compose exec -u node n8n n8n import:workflow --input=/home/node/.n8n/workflows/
```
