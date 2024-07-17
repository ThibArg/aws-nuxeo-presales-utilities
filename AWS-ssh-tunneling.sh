#!/bin/bash

echo "=================================================="
echo "⚠️ THIS SCRIPT IS OBSOLETE ⚠️"
echo "=================================================="
echo "See the final script at https://github.com/nuxeo-sandbox/presales-vmdemo/blob/master/EC2-instance-connect-tools/helper-scripts/unix/nxpssh.sh"
echo ""
exit -1

# ==================================================
# ==================================================
# ==================================================

function printHelp {
  echo "Usage:"
  echo "./AWS-ssh-tunnelling.sh -n instance_name_or_URL -r region -p profile"
  echo "-n instance name or url, required"
  echo "   If a URL, the instance name is still the prefix (we don't use Route53 to find the corresponding instance)"
  echo "   So, if the instance name is my-demo, you can pass -n my-demo or -n my-demo.cloud.nuxeo.com"
  echo "-r region, optional."
  echo "   If not specified, it must be either set in the AWS_REGION env. variable or set in the profile"
  echo "   (Value set in AWS_REGION is checked before the one stored in the profile)"
  echo "-p profile, optional (\"default\" if not set)"
  echo ""
  echo "Examples:"
  echo "Using default profile and region set in AWS_REGION or in the default profile"
  echo "./AWS-ssh-tunnelling.sh -n my-demo"
  echo ""
  echo "Using default profile and region set in AWS_REGION or in the default profile"
  echo "./AWS-ssh-tunnelling.sh -n my-demo.cloud.nuxeo.com"
  echo ""
  echo "Using default profile, forcing another region"
  echo "./AWS-ssh-tunnelling.sh -n my-demo-in-eu -r eu-east-1"
  echo ""
  echo "Using a profile. region is read in the profile config or in AWS_REGION"
  echo "./AWS-ssh-tunnelling.sh my-demo -p custom-profile"
}

# ==================================================
# Parse arguments, check for required.
# ==================================================
instance_name=""
region=""
profile="default"

while getopts ":n:r:p:" opt; do
  case ${opt} in
    n)
      instance_name=$OPTARG
      ;;
    r)
      region=$OPTARG
      ;;
    p)
      profile=$OPTARG
      ;;
    \?)
      printHelp
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Check if name is provided
if [ -z "$instance_name" ]
then
  echo -e "*ERROR* instance_name (-n) is required.\n"
  printHelp
  exit 2
fi

function verboseEcho(msg) {
  if [ $quiet -eq 0 ]; then
    echo msg
  fi
}

# ==================================================
# Cleanup parameters, Get region
# ==================================================
msg="Checking parameters..."
# Cleanup if needed (remove nuxeo.cloud)
if [[ $instance_name == *".cloud.nuxeo.com" ]]; then
  instance_name=${instance_name%.cloud.nuxeo.com}
  msg=$msg"\n  Instance Name: Removing cloud.nuxeo.com => $instance_name"
else
  msg=$msg"\n  Instance Name: $instance_name"
fi

if [ -z "$region" ]
then
  if [ -z "$AWS_REGION" ]
  then
    region=$(aws configure get region --profile $profile)
    msg=$msg"\n  Region: No -r argument, no AWS_REGION defined => Region read from pofile <$profile>: $region"
  else
    region=$AWS_REGION
    msg=$msg"\n  Region: Region read from AWS_REGION: $AWS_REGION"
  fi
fi

msg=$msg"\n  Profile: $profile"

echo -e $msg

# ==================================================
# Find instance Id
# ==================================================
echo -e "\nSearching the id of instance <$instance_name>..."
instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$instance_name" \
    --query 'Reservations[].Instances[].[InstanceId]' \
    --region $region \
    --output text)

if [ -z "$instance_id" ]
then
  echo -e "Instance ID not found for instance name <$instance_name>:\n    Is it running?\n    Is $region the correct region?\n    No mispelling?"
  exit 3
fi

echo "...found. Instance ID is $instance_id"

# ==================================================
# Run
# ==================================================
echo -e "\nOpening the ssh connection via tunneling. Command that we run:"
echo "aws ec2-instance-connect ssh --instance-id $instance_id --os-user ubuntu --connection-type eice --region $region --profile $profile"
aws ec2-instance-connect ssh --instance-id $instance_id --os-user ubuntu --connection-type eice --region $region --profile $profile
