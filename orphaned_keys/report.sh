#!/bin/bash
set -euo pipefail

REGION="us-east-1"  # 🔁 Change as needed
DAYS_LOOKBACK=90

echo "Collecting KMS key data in $REGION..."

# Get all keys
ALL_KEYS=$(aws kms list-keys --region "$REGION" --query 'Keys[*].KeyId' --output text)

# Get all aliased key IDs
ALIASED_KEYS=$(aws kms list-aliases --region "$REGION" \
  --query 'Aliases[*].TargetKeyId' --output text | tr '\t' '\n' | sort | uniq)

# Print header
printf "%-40s | %-8s | %-12s | %-6s | %-20s\n" "KeyId" "State" "Created" "Alias" "LastUsed"
printf '%.0s-' {1..100}; echo

for KEY_ID in $ALL_KEYS; do
  # Get metadata
  META=$(aws kms describe-key --region "$REGION" --key-id "$KEY_ID" | jq -r '.KeyMetadata')
  STATE=$(echo "$META" | jq -r '.KeyState')
  CREATED=$(echo "$META" | jq -r '.CreationDate' | cut -d'T' -f1)

  # Check if aliased
  if echo "$ALIASED_KEYS" | grep -q "$KEY_ID"; then
    ALIAS="Yes"
  else
    ALIAS="No"
  fi

  # CloudTrail last used event
  LAST_USED=$(aws cloudtrail lookup-events \
    --region "$REGION" \
    --lookup-attributes AttributeKey=EventSource,AttributeValue=kms.amazonaws.com \
    --max-results 100 \
    --query 'Events[?contains(CloudTrailEvent, `'"$KEY_ID"'`)] | [0].EventTime' \
    --output text 2>/dev/null || echo "N/A")

  printf "%-40s | %-8s | %-12s | %-6s | %-20s\n" "$KEY_ID" "$STATE" "$CREATED" "$ALIAS" "$LAST_USED"
done
