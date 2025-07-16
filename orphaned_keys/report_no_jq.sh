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
  --lookup-attributes AttributeKey=EventSource,AttributeValue=kms.amazona
