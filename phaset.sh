#!/bin/bash -l

set -eo pipefail #euo

MANIFEST_FILE="phaset.manifest.json"
LINT_FILE="standardlint.json"
RESULTS_FILE="standardlint.results.json"
DEPLOYMENT_FILE="deployment.json"

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --org-id)
      ORG_ID="$2"
      shift 2
      ;;
    --record-id)
      RECORD_ID="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --endpoint)
      INTEGRATION_API_URL="$2"
      shift 2
      ;;
    --action)
      ACTION="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      return 1
      ;;
    esac
  done
}

validate_arguments() {
  if [ -z "${ORG_ID:-}" ]; then
    if [[ -f "$MANIFEST_FILE" ]]; then
      ORG_ID=$(grep -o '"organizationId"[[:space:]]*:[[:space:]]*".*"' "$MANIFEST_FILE" | awk -F':' '{gsub(/[", ]/, "", $2); print $2}')
    fi

    if [ -z "${ORG_ID:-}" ]; then
      echo "❌ ERROR: ORG_ID is not set and could not be inferred from '$MANIFEST_FILE'!" >&2
      return 1
    fi
  fi

  if [ -z "${RECORD_ID:-}" ]; then
    if [[ -f "$MANIFEST_FILE" ]]; then
      RECORD_ID=$(grep -o '"id"[[:space:]]*:[[:space:]]*".*"' "$MANIFEST_FILE" | awk -F':' '{gsub(/[", ]/, "", $2); print $2}')
    fi

    if [ -z "${RECORD_ID:-}" ]; then
      echo "❌ ERROR: RECORD_ID is not set and could not be inferred from '$MANIFEST_FILE'!" >&2
      return 1
    fi
  fi

  if [ -z "${TOKEN:-}" ]; then
    echo "❌ ERROR: TOKEN is not set!" >&2
    return 1
  fi

  if [ -z "${INTEGRATION_API_URL:-}" ]; then
    echo "❌ ERROR: ENDPOINT is not set!" >&2
    return 1
  fi

  if [ -z "${ACTION:-}" ]; then
    echo "❌ ERROR: ACTION is not set!" >&2
    return 1
  fi
}

send_request() {
  local url="$1"
  local method="$2"
  local data_file="$3"

  if [[ -n "${MOCK_CURL_FAILURE:-}" ]]; then
    echo "❌ Mocked HTTP call failed." >&2
    return 1
  fi

  if [[ -n $data_file ]]; then
    RAW_RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
      -d @"$data_file" -H "Content-Type: application/json")
  else
    RAW_RESPONSE=$(
      curl -s -w "\n%{http_code}" -X "$method" "$url"
    )
  fi

  RESPONSE_BODY=$(echo "$RAW_RESPONSE" | sed '$d')
  HTTP_STATUS=$(echo "$RAW_RESPONSE" | tail -n 1)

  if [[ -z "$HTTP_STATUS" || "$HTTP_STATUS" -ne 200 ]]; then
    echo "❌ ERROR: Request failed. HTTP Status: $HTTP_STATUS" >&2
    echo "Response: $RESPONSE_BODY" >&2
    return 1
  fi

  echo "✅ Request succeeded with HTTP Status: $HTTP_STATUS"
}

function get_baseline_id() {
  json_object=$(cat "$MANIFEST_FILE" | tr ',' '\n')

  baseline_id=$(printf -- '%s\n' "${json_object}" | awk -F ':' '
    /"baseline"/ { in_baseline = 1 }
    in_baseline && /"id"/ { gsub(/"/, "", $NF); print $NF; in_baseline = 0 }
')

  echo ${baseline_id:-default}
}

handle_deployment() {
  local current_git_sha

  if ! command -v git >/dev/null 2>&1; then
    echo "❌ ERROR: Git is not installed. Cannot proceed with deployment." >&2
    return 1
  fi

  if ! current_git_sha=$(git log --pretty=format:'%H' -n 1 2>/dev/null); then
    echo "⚠️ WARNING: Git repository has no commits or is invalid. Using fallback SHA." >&2
    current_git_sha="demo_commit_sha"
  fi

  cat >"$DEPLOYMENT_FILE" <<EOF
{
  "event": "deployment",
  "commitSha": "$current_git_sha"
}
EOF

  local url="$INTEGRATION_API_URL/event/$ORG_ID/$RECORD_ID/$TOKEN"
  if ! send_request "$url" "POST" "$DEPLOYMENT_FILE"; then
    echo "❌ ERROR: Failed to send deployment data." >&2
    rm -f "$DEPLOYMENT_FILE"
    return 1
  fi

  echo "✅ Deployment data successfully sent."
  rm -f "$DEPLOYMENT_FILE"
  return 0
}

handle_standards() {
  if command -v node &>/dev/null; then
    local baseline_id=""

    baseline_id=$(get_baseline_id)

    local url="$INTEGRATION_API_URL/baselines/$ORG_ID/$baseline_id/$RECORD_ID/$TOKEN"

    curl -s -o "$LINT_FILE" "$url"

    npm install standardlint
    npx standardlint --output

    rm -f $LINT_FILE
  else
    echo "❌ Node.js is required to generate Standards output. Please make sure you have Node and NPM in your environment."
    exit 1
  fi

  if [[ -f "$RESULTS_FILE" ]]; then
    local url="$INTEGRATION_API_URL/standards/$ORG_ID/$RECORD_ID/$TOKEN"

    send_request "$url" "POST" "$RESULTS_FILE"

    rm -f $RESULTS_FILE
  else
    echo "⚠️ No standards results file found; skipping."
  fi
}

handle_record() {
  echo "Uploading record to Phaset..."

  local url="$INTEGRATION_API_URL/record/$ORG_ID/$RECORD_ID/$TOKEN"

  send_request "$url" "POST" "$MANIFEST_FILE"
}

main() {
  parse_arguments "$@" || exit 1
  validate_arguments || exit 1

  if [[ -f "$MANIFEST_FILE" ]]; then
    case "$ACTION" in
    "deployment")
      handle_deployment
      ;;
    "standards")
      handle_standards
      ;;
    "record")
      handle_record
      ;;
    *)
      echo "❌ ERROR: Invalid action: $ACTION" >&2
      exit 1
      ;;
    esac

    echo "✅ Phaset has completed successfully!"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi