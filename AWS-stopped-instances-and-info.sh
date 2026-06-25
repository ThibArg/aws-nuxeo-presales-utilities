#!/bin/bash
# stopped-ec2-report.sh
# Generates a CSV report of stopped EC2 instances across all regions.
# Requirements: aws cli v2, jq, active SSO session (aws sso login).

set -euo pipefail

OUTPUT="stopped-ec2-report-$(date +%Y%m%d-%H%M%S).csv"

# Placeholder used when CloudTrail has no matching event
# (typically because it falls outside the default 90-day retention window)
NOT_FOUND="> 3 months"

echo "Generating report of stopped EC2 instances across all regions..."
echo -e "    ⚠️        ⚠️        ⚠️\n    For stopped instances, getting the last launch time and user requires CloudTrail which slows down the script. \n    ⚠️        ⚠️        ⚠️\n"

# CSV header
echo "Region,InstanceId,InstanceName,InstanceType,CreationDate,CreationUser,LastLaunchTime,LastLaunchUser" > "$OUTPUT"

# Small helper to escape commas / quotes in CSV fields
csv_escape() {
  local s="${1:-}"
  if [[ "$s" == *,* || "$s" == *\"* || "$s" == *$'\n'* ]]; then
    s="${s//\"/\"\"}"
    printf '"%s"' "$s"
  else
    printf '%s' "$s"
  fi
}

# Extract only the date part (YYYY-MM-DD)
iso_date_only() {
  local s="${1:-}"
  if [[ "$s" == "$NOT_FOUND" || -z "$s" ]]; then
    printf '%s' "$s"
  else
    printf '%s' "${s:0:10}"
  fi
}

# Get the list of EC2 regions enabled on the account
REGIONS=$(aws ec2 describe-regions \
  --query 'Regions[].RegionName' \
  --output text)

for REGION in $REGIONS; do
  echo "$REGION..."

  # Fetch all stopped instances in the region, including EC2 LaunchTime
  INSTANCES_JSON=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=stopped" \
    --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,Name:Tags[?Key==`Name`]|[0].Value,LaunchTime:LaunchTime}' \
    --output json 2>/dev/null || echo "[]")

  COUNT=$(echo "$INSTANCES_JSON" | jq 'length')
  if [[ "$COUNT" -eq 0 ]]; then
    echo "  No stopped instances found"
    continue
  fi

  echo "  $COUNT stopped instance(s) found"

  # Progress counter for CloudTrail processing in this region
  PROCESSED=0

  # Use process substitution so the loop runs in the current shell
  while read -r row; do
    ID=$(echo "$row"   | jq -r '.Id')
    TYPE=$(echo "$row" | jq -r '.Type')
    NAME=$(echo "$row" | jq -r '.Name // "N/A"')

    # Creation date comes from EC2 LaunchTime (instance attribute)
    CREATION_DATE=$(echo "$row" | jq -r '.LaunchTime // empty')
    CREATION_DATE=$(iso_date_only "$CREATION_DATE")
    if [[ -z "$CREATION_DATE" ]]; then
      CREATION_DATE="$NOT_FOUND"
    fi

    # --- RunInstances event (creation user): take the oldest one
    RUN_EVENT=$(aws cloudtrail lookup-events \
      --region "$REGION" \
      --lookup-attributes AttributeKey=ResourceName,AttributeValue="$ID" \
      --query 'Events[?EventName==`RunInstances`] | [-1]' \
      --output json 2>/dev/null || echo "null")

    CREATION_USER="$NOT_FOUND"
    if [[ "$RUN_EVENT" != "null" && -n "$RUN_EVENT" ]]; then
      CREATION_USER=$(echo "$RUN_EVENT" | jq -r --arg nf "$NOT_FOUND" '.Username // $nf')
    fi

    # --- StartInstances event (last launch): take the most recent one
    START_EVENT=$(aws cloudtrail lookup-events \
      --region "$REGION" \
      --lookup-attributes AttributeKey=ResourceName,AttributeValue="$ID" \
      --query 'Events[?EventName==`StartInstances`] | [0]' \
      --output json 2>/dev/null || echo "null")

    LAST_LAUNCH_TIME="$NOT_FOUND"
    LAST_LAUNCH_USER="$NOT_FOUND"
    if [[ "$START_EVENT" != "null" && -n "$START_EVENT" ]]; then
      LAST_LAUNCH_TIME=$(echo "$START_EVENT" | jq -r --arg nf "$NOT_FOUND" '.EventTime // $nf')
      LAST_LAUNCH_USER=$(echo "$START_EVENT" | jq -r --arg nf "$NOT_FOUND" '.Username // $nf')
    fi

    # Keep only the date part for date columns
    LAST_LAUNCH_TIME=$(iso_date_only "$LAST_LAUNCH_TIME")

    # Write the CSV row
    {
      printf '%s,'  "$(csv_escape "$REGION")"
      printf '%s,'  "$(csv_escape "$ID")"
      printf '%s,'  "$(csv_escape "$NAME")"
      printf '%s,'  "$(csv_escape "$TYPE")"
      printf '%s,'  "$(csv_escape "$CREATION_DATE")"
      printf '%s,'  "$(csv_escape "$CREATION_USER")"
      printf '%s,'  "$(csv_escape "$LAST_LAUNCH_TIME")"
      printf '%s\n' "$(csv_escape "$LAST_LAUNCH_USER")"
    } >> "$OUTPUT"

    # Progress message every 5 instances
    PROCESSED=$((PROCESSED + 1))
    if (( PROCESSED % 5 == 0 )); then
      echo "    $PROCESSED..."
    fi
  done < <(echo "$INSTANCES_JSON" | jq -c '.[]')

  echo "   Done with $REGION ($PROCESSED / $COUNT processed)"
done

echo "Report generated: $OUTPUT"
