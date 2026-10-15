#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/common.sh
aws sqs send-message --queue-url "$(output "$PROJECT_NAME-reports" QueueUrl)" \
  --message-body "{\"week\": \"$1\", \"source\": \"sqs\"}"