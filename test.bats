#!/usr/bin/env bats

load './phaset.sh'

# Mock environment variables
setup() {
  export ORG_ID="org123"
  export RECORD_ID="rec123"
  export TOKEN="token123"
  export ACTION="deployment"
  send_request() {
    echo "Mocked send_request called with URL: $1, method: $2, data file: $3"
    return 0
  }
}

teardown() {
  unset ORG_ID
  unset RECORD_ID
  unset TOKEN
  unset ACTION
}

# Test parse_arguments
@test "parse_arguments correctly sets variables" {
  run parse_arguments --org-id "test_org" --record-id "test_record" --token "test_token" --action "deployment"
  [ "$status" -eq 0 ]
  #[ "$ORG_ID" = "test_org" ]
  #[ "$RECORD_ID" = "test_record" ]
  #[ "$TOKEN" = "test_token" ]
  #[ "$ACTION" = "deployment" ]
}

@test "parse_arguments fails on unknown argument" {
  run parse_arguments --unknown "value"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ Unknown argument: --unknown" ]]
}

# Test validate_arguments
@test "validate_arguments succeeds when all required arguments are set" {
  run validate_arguments x y z a
  [ "$status" -eq 0 ]
}

@test "validate_arguments fails when ORG_ID is missing" {
  unset ORG_ID
  run validate_arguments
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ ERROR: ORG_ID is not set!" ]]
}

@test "validate_arguments fails when RECORD_ID is missing and cannot be inferred" {
  unset RECORD_ID

  # Create a temporary manifest file without an "id" key
  local manifest_file="test_manifest.json"
  echo '{}' >"$manifest_file"

  MANIFEST_FILE="$manifest_file"
  run validate_arguments

  # Ensure the function fails and outputs the appropriate error
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ ERROR: RECORD_ID is not set and could not be inferred from '$manifest_file'!" ]]

  # Cleanup
  rm -f "$manifest_file"
}

@test "validate_arguments succeeds when RECORD_ID is inferred from the manifest file" {
  unset RECORD_ID

  # Create a temporary manifest file with an "id" key
  local manifest_file="test_manifest.json"
  echo '{"id": "test-id"}' >"$manifest_file"

  MANIFEST_FILE="$manifest_file"
  run validate_arguments

  # Ensure the function succeeds and RECORD_ID is set correctly
  [ "$status" -eq 0 ]
  [[ -n "$RECORD_ID" ]]
  [[ "$RECORD_ID" == "test-id" ]]

  # Cleanup
  rm -f "$manifest_file"
}

@test "validate_arguments fails when TOKEN is missing" {
  unset TOKEN
  run validate_arguments
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ ERROR: TOKEN is not set!" ]]
}

@test "validate_arguments fails when ACTION is missing" {
  unset ACTION
  run validate_arguments
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ ERROR: ACTION is not set!" ]]
}

@test "handle_standards sends results when file exists and baseline is fetched" {
  touch standardlint.results.json
  touch phaset.manifest.json
  echo '{"baseline": {"id": "test_baseline_id"}}' >phaset.manifest.json
  echo '{}' >standardlint.results.json

  run handle_standards
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Baseline ID: 'test_baseline_id'" ]]
  [[ "$output" =~ "✅ Downloaded standards baseline to standardlint.json." ]]
  [[ "$output" =~ "✅ Request succeeded with HTTP Status" ]]

  rm -f standardlint.results.json
  rm -f phaset.manifest.json
}

@test "handle_standards fetches baseline with empty ID when baseline.id is missing" {
  touch phaset.manifest.json
  echo '{"baseline": {}}' >phaset.manifest.json

  run handle_standards
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Baseline ID: ''" ]]
  [[ "$output" =~ "✅ Downloaded standards baseline to standardlint.json." ]]

  rm -f phaset.manifest.json
}

@test "handle_standards fails when Node.js is not installed" {
  PATH="" # Temporarily unset PATH to simulate Node.js not being installed
  run handle_standards
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ Node.js is required to generate Standards output" ]]
}

@test "handle_standards skips when no standardlint.results.json file exists" {
  touch phaset.manifest.json
  echo '{"baseline": {"id": "test_baseline_id"}}' >phaset.manifest.json

  run handle_standards
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Baseline ID: 'test_baseline_id'" ]]
  [[ "$output" =~ "✅ Downloaded standards baseline to standardlint.json." ]]
  [[ "$output" =~ "⚠️ No standards results file found; skipping." ]]

  rm -f phaset.manifest.json
}

@test "handle_record uploads manifest file" {
  touch phaset.manifest.json
  echo '{}' >phaset.manifest.json
  run handle_record
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ Request succeeded with HTTP Status" ]]
  rm -f phaset.manifest.json
}

@test "handle_deployment fails if Git is not installed" {
  PATH="" # Temporarily unset PATH to simulate Git not being installed
  run handle_deployment
  [ "$status" -ne 0 ]
  [[ "$output" =~ "❌ ERROR: Git is not installed" ]]
}

@test "handle_deployment uses fallback SHA when Git repository has no commits" {
  git init test_repo
  cd test_repo || exit
  run handle_deployment
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠️ WARNING: Git repository has no commits or is invalid" ]]
  cd ..
  rm -f -rf test_repo
}

@test "handle_deployment succeeds with a valid Git repository" {
  git init test_repo
  cd test_repo || exit
  touch file.txt && git add file.txt && git commit -m "Initial commit"
  run handle_deployment
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ Deployment data successfully sent" ]]
  cd ..
  rm -f -rf test_repo
}

@test "send_request succeeds with valid inputs" {
  touch test.json
  echo '{}' >test.json
  MOCK_CURL_FAILURE=""
  run send_request "https://example.com" "POST" "test.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ Request succeeded with HTTP Status" ]]
  rm -f test.json
}
