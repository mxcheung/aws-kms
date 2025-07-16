#!/bin/bash
set -euo pipefail

REGION="us-east-1"  # 🔁 Change as needed
MAX_CLOUDTRAIL_EVENTS=100

echo "Collecting KMS key data in $REGION..."

# Get all keys
ALL_KEYS=$(aws kms list-keys --region "$REGION" --query 'Keys[*].KeyId' --output text)

# Get all aliased key target IDs (some aliases may have no TargetKeyId)
ALIASED_KEYS=$(aws kms list-aliases --region "$REGION" \
  --query 'Aliases[?TargetKeyId!=null].TargetKeyId' \
  --output text | tr '\t' '\n' | sort | uniq)

# Get recent CloudTrail KMS events (max limit of 90 days unless you have CloudTrail Lake)
CLOUDTRAIL_EVENTS=$(aws cloudtrail lookup-events \
  --region "$REGION" \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=kms.amazonaws.com \
  --max-results "$MAX_CLOUDTRAIL_EVENTS" \
  --output text \
  --query 'Events[*].[EventTime, CloudTrailEvent]')

# Print header
printf "%-40s | %-8s | %-12s | %-6s | %-20s\n" "KeyId" "State" "Created" "Alias" "LastUsed"
printf '%.0s-' {1..100}; echo

for KEY_ID in $ALL_KEYS; do
  # Get key description
  DESC=$(aws kms describe-key --region "$REGION" --key-id "$KEY_ID" --output text \
    --query 'KeyMetadata.[KeyId,KeyState,CreationDate]')

  # Parse output
  KEY_STATE=$(echo "$DESC" | awk '{print $2}')
  CREATED_DATE=$(echo "$DESC" | awk '{print $3}' | cut -d'T' -f1)

  # Check if aliased
  if echo "$ALIASED_KEYS" | grep -q "$KEY_ID"; then
    ALIAS="Yes"
  else
    ALIAS="No"
  fi

  # Check if key is mentioned in any CloudTrailEvent JSON
  LAST_USED="N/A"
  while IFS=$'\t' read -r EVENT_TIME CT_EVENT_JSON; do
    if echo "$CT_EVENT_JSON" | grep -q "$KEY_ID"; then
      LAST_USED="$EVENT_TIME"
      break
    fi
  done <<< "$CLOUDTRAIL_EVENTS"

  printf "%-40s | %-8s | %-12s | %-6s | %-20s\n" "$KEY_ID" "$KEY_STATE" "$CREATED_DATE" "$ALIAS" "$LAST_USED"
done
