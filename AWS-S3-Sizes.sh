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

# Get the list of all S3 buckets
buckets=$(aws s3api list-buckets --query "Buckets[*].Name" --output text)

# Print header
echo ""
printf '%-50s %-20s\n' '--------------------------------------------------''--------------------'
printf "%-50s %-20s\n" "Bucket Name" "Total Size"
printf '%-50s %-20s\n' '--------------------------------------------------''--------------------'

# Initialize total size in bytes
total_size_bytes=0

# Iterate through each bucket and calculate its size
for bucket in $buckets; do

    # Display message because some buckets will take time to calculate
    echo -ne "$bucket...\r"
    #calculate
    size=$(calculate_bucket_size $bucket)
    #Clear message
    echo -ne "\r\033[K"

    size_value=$(echo $size | awk '{print $1}')
    size_unit=$(echo $size | awk '{print $2}')

    printf "%-50s %-20s\n" "$bucket" "$size"
    
    # Convert size to bytes and add to total size
    size_in_bytes=$(convert_to_bytes $size_value $size_unit)
    total_size_bytes=$(echo "$total_size_bytes + $size_in_bytes" | bc)
done

# Function to convert bytes to human-readable format
human_readable_size() {
    local size=$1
    local units=("Bytes" "KiB" "MiB" "GiB" "TiB")
    local unit_index=0

    while (( $(echo "$size >= 1024" | bc -l) && unit_index < ${#units[@]} - 1 )); do
        size=$(echo "$size / 1024" | bc -l)
        unit_index=$((unit_index + 1))
    done

    # Round the size to two decimal places
    size=$(printf "%.2f" $size)
    echo "$size ${units[$unit_index]}"
}

# Convert total size to human-readable format
total_size_human=$(human_readable_size $total_size_bytes)

# Print total size of all buckets
printf '%-50s %-20s\n' '--------------------------------------------------''--------------------'
printf "%-50s %-20s\n" "Total Size" "$total_size_human"
printf '%-50s %-20s\n' '--------------------------------------------------''--------------------'
echo ""