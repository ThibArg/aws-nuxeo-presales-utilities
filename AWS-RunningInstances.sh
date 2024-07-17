#!/bin/bash
# You are supposed to be logged in to AWS to run this script (aws sso login)

# Get a list of all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# Header for the output
report="Running instances\n--------------------------------------------------\n"
report="$report"$(printf "%-20s %-30s\n" "Region" "InstanceName")
report="$report\n--------------------------------------------------\n"

# Iterate over each region
for region in $regions; do

  echo -ne "$region...\r"

  gotOne=0

  # Get running instances in the region
  instances=$(aws ec2 describe-instances --region $region --filters "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0]]" --output text)

  # Clear the processing message
  echo -ne "\r\033[K"

  # Process each instance
  while read -r instance_name; do
    if [ -n "$instance_name" ]; then
      gotOne=1
      report="$report"$(printf  "%-20s %-30s\n" "$region" "$instance_name")"\n"
    fi
  done <<< "$instances"

  if [ "$gotOne" -eq 1 ]; then
    report="$report--------------------------------------------------\n"
  fi
done

printf "\n$report\n\n"


