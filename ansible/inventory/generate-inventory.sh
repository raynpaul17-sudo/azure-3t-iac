#!/usr/bin/bash
set -euo pipefail

# Find script folder and project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../../terraform"
OUTPUT_FILE="${SCRIPT_DIR}/hosts.generated.yaml"

# Check required tools
command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' is not found" >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Error: 'terraform' is not found" >&2; exit 1; }

# Read Terraform state as JSON
TF_JSON="$(terraform -chdir="${TF_DIR}" output -json)"

# Extract values with jq
LB_IP="$(echo "${TF_JSON}" | jq -r '.lb_public_ip.value')"
BACK_IP="$(echo "${TF_JSON}" | jq -r '.vm_private_ips.value["back"]')"
DB_IP="$(echo "${TF_JSON}" | jq -r '.vm_private_ips.value["db"]')"
ADMIN_USERNAME="$(echo "${TF_JSON}" | jq -r '.adminusername["value"]')"
SSH_FRONTEND_PORT="$(echo "${TF_JSON}" | jq -r '.ssh_frontend_port["value"]')"
FRONT_CIDR="$(echo "${TF_JSON}" | jq -r '.subnet_address_prefixes.value["front"]')"
BACK_CIDR="$(echo "${TF_JSON}" | jq -r '.subnet_address_prefixes.value["back"]')"
DB_CIDR="$(echo "${TF_JSON}" | jq -r '.subnet_address_prefixes.value["db"]')"
ADMIN_IP="$(echo "${TF_JSON}" | jq -r '.admin_ip.value')"
LB_PUBLIC_IP="$(echo "${TF_JSON}" | jq -r '.lb_public_ip.value')"
KEYVAULT_URI="$(echo "${TF_JSON}" | jq -r '.keyvault_uri.value')"
KEYVAULT_URI="${KEYVAULT_URI%/}"
KEYVAULT_SECRET_NAME="$(echo "${TF_JSON}" | jq -r '.keyvault_secret_name.value')"

# Fail if a Terraform output is missing or empty
require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    echo "Error: Terraform output '${name}' is missing or empty." >&2
    exit 1
  fi
}

# Check required values
require_value "lb_public_ip"         "${LB_IP}"
require_value "vm_private_ips.back"  "${BACK_IP}"
require_value "vm_private_ips.db"    "${DB_IP}"
require_value "adminusername"        "${ADMIN_USERNAME}"
require_value "ssh_frontend_port"    "${SSH_FRONTEND_PORT}"
require_value "subnet_address_prefixes.front" "${FRONT_CIDR}"
require_value "subnet_address_prefixes.back"  "${BACK_CIDR}"
require_value "subnet_address_prefixes.db"    "${DB_CIDR}"
require_value "admin_ip"             "${ADMIN_IP}"
require_value "keyvault_uri"         "${KEYVAULT_URI}"
require_value "keyvault_secret_name" "${KEYVAULT_SECRET_NAME}"

# Write Ansible inventory file
cat <<EOF > "${OUTPUT_FILE}"
all:
  vars:
    ansible_user: "${ADMIN_USERNAME}"
    subnet_front: "${FRONT_CIDR}"
    subnet_back: "${BACK_CIDR}"
    subnet_db: "${DB_CIDR}"
    admin_ip: "${ADMIN_IP}"
    lb_public_ip: "${LB_PUBLIC_IP}"
    keyvault_uri: "${KEYVAULT_URI}"
    keyvault_secret_name: "${KEYVAULT_SECRET_NAME}"
  children:
    front:
      hosts:
        vm-front:
          ansible_host: "${LB_IP}"
          ansible_port: ${SSH_FRONTEND_PORT}
    back:
      hosts:
        vm-back:
          ansible_host: "${BACK_IP}"
      vars:
        ansible_ssh_common_args: "-o ProxyJump=${ADMIN_USERNAME}@${LB_IP}:${SSH_FRONTEND_PORT}"
    db:
      hosts:
        vm-db:
          ansible_host: "${DB_IP}"
      vars:
        ansible_ssh_common_args: "-o ProxyJump=${ADMIN_USERNAME}@${LB_IP}:${SSH_FRONTEND_PORT}"
EOF

# Set permissions
chmod 644 "${OUTPUT_FILE}"
echo "Inventory generated: ${OUTPUT_FILE}"
