#!/bin/bash

# Check if a tag name parameter is provided
if [ -z "$1" ]; then
    echo "Error: No tag name provided."
    echo "Usage: AWS-InstancesWithATag.sh <TagName>"
    exit 1
fi

TAG_NAME="$1"

# Get all available regions
regions=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

# Print header
printf '%-20s %-35s %-20s\n' '--------------------''-----------------------------------''--------------------'
printf "%-20s %-35s %-20s\n" "Region" "InstanceName" "$TAG_NAME"
printf '%-20s %-35s %-20s\n' '--------------------''-----------------------------------''--------------------'

# Iterate through each region
for region in $regions; do

  echo -ne "$region...\r"

  # Describe instances with the tag
  instances=$(aws ec2 describe-instances --region "$region" --filters "Name=tag-key,Values=$TAG_NAME" --query "Reservations[*].Instances[*].[InstanceId,Tags]" --output json)
  
  # Clear processing info
  echo -ne "\033[K"

  # Check if instances were found
  if [ "$instances" != "[]" ]; then
    # Process each instance
    for instance in $(echo "${instances}" | jq -r '.[][] | @base64'); do
      _jq() {
        echo ${instance} | base64 --decode | jq -r ${1}
      }

      instance_id=$(_jq '.[0]')
      tags=$(_jq '.[1]')
      instance_name=""
      tag_value=""

      # Retrieve instance name and tag value
      for tag in $(echo "${tags}" | jq -r '.[] | @base64'); do
        _tag() {
            echo ${tag} | base64 --decode | jq -r ${1}
        }
        key=$(_tag '.Key')
        value=$(_tag '.Value')
        if [ "$key" == "Name" ]; then
          instance_name=$value
        elif [ "$key" == "$TAG_NAME" ]; then
          tag_value=$value
        fi
      done

      # Print instance details
      printf "%-20s %-35s %-20s\n" "$region" "$instance_name" "$tag_value"
    done
    printf '%-20s %-35s %-20s\n' '--------------------''-----------------------------------''--------------------'
  fi
done
echo ""
