#!/bin/bash

# Fetch all the regions
echo "Fetching regions..."
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

all_instances="All instances\n"

# Loop through each region to get the instances
for region in $regions; do
    echo "Instances in $region..."
    # List all instances in the current region
    echo -e "\n$region" >> all_instances;
    aws ec2 describe-instances \
        --region $region \
        --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value | [0], State.Name]" \
        --output table  >> all_instances ;
done
echo -e "====================> DONE" >> all_instances;

echo "------------------------------"
echo "DONE"
echo "------------------------------" 
cat all_instances
