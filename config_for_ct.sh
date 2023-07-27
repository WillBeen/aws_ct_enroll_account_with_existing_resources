#!bash

# This script has been modified to delete the recorders and delivery channels in all the managed regions

export PROTECTED_ACCOUNTS="123123123123 456456456456 789789789789"
export ORGANIZATION_ID=o-abc12
export LOGGING_ACCOUNT=456456456456
export AUDIT_ACCOUNT=789789789789
export CURRENT_REGION="eu-central-1 sa-east-1 ap-southeast-1 us-east-1"
export HOME_REGION="eu-central-1"

export AWS_PAGER=""
export MEMBER_ACCOUNT_NUMBER=$(aws sts get-caller-identity | jq -r '.Account')

# Stopping this script if connected on a protected account
if [[ $PROTECTED_ACCOUNTS =~ $MEMBER_ACCOUNT_NUMBER ]]; then
    echo "This script is not allowed to run on a protected account."
    exit 1
fi

for region in $CURRENT_REGION ; do
    echo -e "\nCURRENT_REGION=$region"

    # Modify AWS Config recorder resources
    RECORDER_NAME=$(aws configservice describe-configuration-recorders --region ${region} | jq -r '.ConfigurationRecorders[].name')
    [[ -z "$RECORDER_NAME" ]] && echo "No config recorder in this region" || echo RECORDER_NAME=$RECORDER_NAME
    [[ $region = $HOME_REGION ]] && GLOBAL_RESOURCE_RECORDING=true || GLOBAL_RESOURCE_RECORDING=false
    [[ -z "$RECORDER_NAME" ]] || aws configservice delete-configuration-recorder --configuration-recorder-name ${RECORDER_NAME} --region ${region}

    # # Modify AWS Config delivery channel resources
    DELIVERY_CHANNEL_NAME=$(aws configservice describe-delivery-channels --region ${region} | jq -r '.DeliveryChannels[].name')
    [[ -z "$DELIVERY_CHANNEL_NAME" ]] && echo "No config delivery channel in this region" || echo DELIVERY_CHANNEL_NAME=$DELIVERY_CHANNEL_NAME
     [[ -z "$DELIVERY_CHANNEL_NAME" ]] || aws configservice delete-delivery-channel --delivery-channel-name ${DELIVERY_CHANNEL_NAME} --region ${region}

done
