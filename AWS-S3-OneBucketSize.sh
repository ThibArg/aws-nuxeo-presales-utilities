#!/bin/bash

# Function to calculate the size of a bucket in human-readable format
calculate_bucket_size() {
    local bucket_name=$1
    size=$(aws s3 ls s3://$bucket_name --recursive --human-readable --summarize | grep "Total Size" | awk '{print $3, $4}')
    echo $size
}

# Function to convert human-readable size to bytes
convert_to_bytes() {
    local size=$1
    local unit=$2
    case $unit in
        Bytes) echo "$size" ;;
        KiB) echo "$(echo "$size * 1024" | bc)" ;;
        MiB) echo "$(echo "$size * 1024 * 1024" | bc)" ;;
        GiB) echo "$(echo "$size * 1024 * 1024 * 1024" | bc)" ;;
        TiB) echo "$(echo "$size * 1024 * 1024 * 1024 * 1024" | bc)" ;;
    esac
}

bucket=$1

# Display message because some buckets will take time to calculate
echo -ne "Calculating size of bucket $bucket...\r"
size=$(calculate_bucket_size $bucket)
#Clear message
echo -ne "\r\033[K"

size_value=$(echo $size | awk '{print $1}')

printf "\n$bucket: $size\n\n"
