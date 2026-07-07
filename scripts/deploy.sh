#!/usr/bin/env bash
# End-to-end deploy script for the AWS Infrastructure Monitoring project.
# Usage: ./scripts/deploy.sh [terraform|stack|all]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-all}"

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is required but not installed. Please install it and re-run." >&2
    exit 1
  fi
}

deploy_terraform() {
  echo "==> Checking prerequisites (terraform, aws cli)..."
  check_command terraform
  check_command aws

  echo "==> Verifying AWS credentials..."
  aws sts get-caller-identity >/dev/null || {
    echo "ERROR: AWS credentials not configured. Run 'aws configure' first." >&2
    exit 1
  }

  cd "$ROOT_DIR/terraform"

  if [ ! -f terraform.tfvars ]; then
    echo "ERROR: terraform.tfvars not found." >&2
    echo "Copy terraform.tfvars.example to terraform.tfvars and fill in your values first." >&2
    exit 1
  fi

  echo "==> terraform init"
  terraform init -input=false

  echo "==> terraform validate"
  terraform validate

  echo "==> terraform plan"
  terraform plan -out=tfplan -input=false

  read -r -p "Apply this plan? (yes/no): " CONFIRM
  if [ "$CONFIRM" = "yes" ]; then
    terraform apply -input=false tfplan
    echo "==> Terraform apply complete."
    echo "==> IMPORTANT: Check your inbox and confirm the SNS email subscription!"
  else
    echo "Aborted. No changes applied."
  fi
}

deploy_stack() {
  echo "==> Checking prerequisites (docker, docker compose)..."
  check_command docker

  cd "$ROOT_DIR"

  echo "==> Validating docker-compose.yml"
  docker compose config >/dev/null

  echo "==> Starting Prometheus + Grafana + exporters"
  docker compose up -d

  echo "==> Waiting for services to become healthy..."
  sleep 8
  docker compose ps

  echo ""
  echo "Stack is up:"
  echo "  Prometheus:  http://localhost:9090"
  echo "  Alertmanager: http://localhost:9093"
  echo "  Grafana:     http://localhost:3000  (user: admin / pass: see docker-compose.yml)"
}

case "$MODE" in
  terraform)
    deploy_terraform
    ;;
  stack)
    deploy_stack
    ;;
  all)
    deploy_terraform
    deploy_stack
    ;;
  *)
    echo "Usage: $0 [terraform|stack|all]"
    exit 1
    ;;
esac

echo "==> Done."
