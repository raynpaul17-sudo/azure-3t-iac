#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

TF_JSON="$(terraform -chdir="${TF_DIR}" output -json)"
LB_IP="$(echo "${TF_JSON}" | jq -r '.lb_public_ip.value')"
BACK_IP="$(echo "${TF_JSON}" | jq -r '.vm_private_ips.value["back"]')"
DB_IP="$(echo "${TF_JSON}" | jq -r '.vm_private_ips.value["db"]')"

cd "${SCRIPT_DIR}/../ansible"

failures=0

if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  RESET=$'\033[0m'
else
  GREEN=""
  RED=""
  RESET=""
fi

check_flow_vm(){
  local description="$1"
  local expected="$2"
  shift 2
  local actual=""

  if "$@" >/dev/null 2>&1; then
    actual="pass"
  else
    actual="fail"
  fi

  if [[ "${actual}" == "${expected}" ]]; then
    printf "  ${GREEN}[OK]   %-28s %s\n${RESET}" "${description}" "${expected}"
  else
    printf "  ${RED}[FAIL] %-28s got %s, expected %s\n${RESET}" "${description}" "${actual}" "${expected}"
    failures=$((failures + 1))
  fi
}

check_http(){
  local description="$1"
  local url="$2"
  local expected="$3"
  local actual=""

  actual="$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 5 "${url}" || echo "000")"

  if [[ "${actual}" == "${expected}" ]]; then
    printf "  ${GREEN}[OK]   %-28s %s\n${RESET}" "${description}" "${actual}"
  else
    printf "  ${RED}[FAIL] %-28s got %s, expected %s\n${RESET}" "${description}" "${actual}" "${expected}"
    failures=$((failures + 1))
  fi
}

printf "\nNetwork isolation checks\n"

check_flow_vm "front -> back:8080" "pass" \
  ansible front -m shell -a "nc -z -w 3 ${BACK_IP} 8080"

check_flow_vm "front -> db:22" "pass" \
  ansible front -m shell -a "nc -z -w 3 ${DB_IP} 22"

check_flow_vm "back -> db:5432" "pass" \
  ansible back -m shell -a "nc -z -w 3 ${DB_IP} 5432"

check_flow_vm "front -> db:5432" "fail" \
  ansible front -m shell -a "nc -z -w 3 ${DB_IP} 5432"

check_flow_vm "back -> db:22" "fail" \
  ansible back -m shell -a "nc -z -w 3 ${DB_IP} 22"

check_flow_vm "db -> back:8080" "fail" \
  ansible db -m shell -a "nc -z -w 3 ${BACK_IP} 8080"

printf "\nExternal exposure checks\n"

check_flow_vm "LB:2222 ssh" "pass" \
  nc -z -w 3 "${LB_IP}" 2222

check_flow_vm "LB:5432 postgres" "fail" \
  nc -z -w 3 "${LB_IP}" 5432

check_flow_vm "LB:8080 app" "fail" \
  nc -z -w 3 "${LB_IP}" 8080


printf "\nHTTP endpoint checks\n"

check_http "LB:80 /healthz"  "http://${LB_IP}/healthz" "200"
check_http "LB:80 / redirect" "http://${LB_IP}/"       "301"
check_http "LB:443 /health"  "https://${LB_IP}/health" "200"
check_http "LB:443 /db"      "https://${LB_IP}/db"     "200"

printf "\n%d check(s) failed\n" "${failures}"

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi
