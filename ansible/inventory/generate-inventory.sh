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

# Check required values
if [[ -z "${LB_IP}" || "${LB_IP}" == "null" ]]; then
  echo "Error: 'lb_public_ip' is not provided." >&2
  exit 1
fi

if [[ -z "${ADMIN_USERNAME}" || "${ADMIN_USERNAME}" == "null" ]]; then
  echo "Error: 'adminusername' is not provided." >&2
  exit 1
fi

if [[ -z "${SSH_FRONTEND_PORT}" || "${SSH_FRONTEND_PORT}" == "null" ]]; then
  echo "Error: 'ssh frontend port' is not provided." >&2
  exit 1
fi

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