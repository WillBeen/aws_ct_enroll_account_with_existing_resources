#!bash

export PROTECTED_ACCOUNTS="123123123123 456456456456 789798789789"
export ORGANIZATION_ID=o-abc123
export LOGGING_ACCOUNT=123456789123
export AUDIT_ACCOUNT=456789456789
export CURRENT_REGION="eu-central-1 sa-east-1 ap-southeast-1 us-east-1"
export HOME_REGION="eu-central-1"

export AWS_PAGER=""
export MEMBER_ACCOUNT_NUMBER=$(aws sts get-caller-identity | jq -r '.Account')

# Stopping this script if connected on a protected account
if [[ $PROTECTED_ACCOUNTS =~ $MEMBER_ACCOUNT_NUMBER ]]; then
    echo "This script is not allowed to run on a protected account."
    exit 1
fi

# Creation of the Config recorder role
echo aws cloudformation deploy --template-file cfn_parts/config_recorder_role.yaml --stack-name CustomerCreatedConfigRecorderRoleForControlTower --region us-east-1 --capabilities CAPABILITY_NAMED_IAM
aws cloudformation deploy --template-file cfn_parts/config_recorder_role.yaml --stack-name CustomerCreatedConfigRecorderRoleForControlTower --region us-east-1 --capabilities CAPABILITY_NAMED_IAM

for region in $CURRENT_REGION ; do
    echo -e "\nCURRENT_REGION=$region"

    # Modify AWS Config recorder resources
    RECORDER_NAME=$(aws configservice describe-configuration-recorders --region ${region} | jq -r '.ConfigurationRecorders[].name')
    [[ -z "$RECORDER_NAME" ]] && echo "No config recorder in this region" || echo RECORDER_NAME=$RECORDER_NAME
    [[ $region = $HOME_REGION ]] && GLOBAL_RESOURCE_RECORDING=true || GLOBAL_RESOURCE_RECORDING=false
    [[ -z "$RECORDER_NAME" ]] || echo aws configservice put-configuration-recorder --configuration-recorder  name=${RECORDER_NAME},roleARN=arn:aws:iam::${MEMBER_ACCOUNT_NUMBER}:role/aws-controltower-ConfigRecorderRole-customer-created --recording-group allSupported=true,includeGlobalResourceTypes=${GLOBAL_RESOURCE_RECORDING} --region ${region}
    [[ -z "$RECORDER_NAME" ]] || aws configservice put-configuration-recorder --configuration-recorder  name=${RECORDER_NAME},roleARN=arn:aws:iam::${MEMBER_ACCOUNT_NUMBER}:role/aws-controltower-ConfigRecorderRole-customer-created --recording-group allSupported=true,includeGlobalResourceTypes=${GLOBAL_RESOURCE_RECORDING} --region ${region}

    # Modify AWS Config delivery channel resources
    DELIVERY_CHANNEL_NAME=$(aws configservice describe-delivery-channels --region ${region} | jq -r '.DeliveryChannels[].name')
    [[ -z "$DELIVERY_CHANNEL_NAME" ]] && echo "No config delivery channel in this region" || echo DELIVERY_CHANNEL_NAME=$DELIVERY_CHANNEL_NAME
    [[ -z "$DELIVERY_CHANNEL_NAME" ]] || echo aws configservice put-delivery-channel --delivery-channel name=${DELIVERY_CHANNEL_NAME},s3BucketName=aws-controltower-logs-${LOGGING_ACCOUNT}-${HOME_REGION},s3KeyPrefix="${ORGANIZATION_ID}",configSnapshotDeliveryProperties={deliveryFrequency=TwentyFour_Hours},snsTopicARN=arn:aws:sns:${region}:${AUDIT_ACCOUNT}:aws-controltower-AllConfigNotifications --region ${region}
    [[ -z "$DELIVERY_CHANNEL_NAME" ]] || aws configservice put-delivery-channel --delivery-channel name=${DELIVERY_CHANNEL_NAME},s3BucketName=aws-controltower-logs-${LOGGING_ACCOUNT}-${HOME_REGION},s3KeyPrefix="${ORGANIZATION_ID}",configSnapshotDeliveryProperties={deliveryFrequency=TwentyFour_Hours},snsTopicARN=arn:aws:sns:${region}:${AUDIT_ACCOUNT}:aws-controltower-AllConfigNotifications --region ${region}

    # Modify AWS Config aggregation authorization resources
    aggregation_authorization_number=$(aws configservice describe-aggregation-authorizations --region ${region} | jq '.AggregationAuthorizations | length')
    [[ ${aggregation_authorization_number} > 0 ]] && echo aws configservice put-aggregation-authorization --authorized-account-id ${AUDIT_ACCOUNT} --authorized-aws-region ${HOME_REGION} --region ${region} || echo "No aggregagion authorization in this region"
    [[ ${aggregation_authorization_number} > 0 ]] && aws configservice put-aggregation-authorization --authorized-account-id ${AUDIT_ACCOUNT} --authorized-aws-region ${HOME_REGION} --region ${region} || echo "No aggregagion authorization in this region"

      # deployment of resources
    if [[ -z "$RECORDER_NAME" || -z "$DELIVERY_CHANNEL_NAME" || ${aggregation_authorization_number} = 0 ]] ; then
        echo resource deployment
        export template_path=cfn_templates/${MEMBER_ACCOUNT_NUMBER}_${region}.yml
        cp cfn_parts/header.yaml ${template_path}
        [[ -z "$RECORDER_NAME" ]] && cat cfn_parts/recorder.yaml >> ${template_path} || true
        [[ -z "$DELIVERY_CHANNEL_NAME" ]] && cat cfn_parts/delivery_channel.yaml >> ${template_path} || true
        [[ ${aggregation_authorization_number} > 0 ]] || cat cfn_parts/aggregation_authorization.yaml >> ${template_path}
        tmp=$(mktemp)
        sed  's/GLOBAL_RESOURCE_RECORDING/'${GLOBAL_RESOURCE_RECORDING}'/g' ${template_path} > ${tmp} ;  mv ${tmp} ${template_path}
        sed  's/HOME_REGION/'${HOME_REGION}'/g' ${template_path} > ${tmp} ;  mv ${tmp} ${template_path}
        sed  's/ORGANIZATION_ID/'${ORGANIZATION_ID}'/g' ${template_path} > ${tmp} ;  mv ${tmp} ${template_path}
        sed  's/LOGGING_ACCOUNT/'${LOGGING_ACCOUNT}'/g' ${template_path} > ${tmp} ;  mv ${tmp} ${template_path}
        sed  's/AUDIT_ACCOUNT/'${AUDIT_ACCOUNT}'/g' ${template_path} > ${tmp} ;  mv ${tmp} ${template_path}
        echo aws cloudformation deploy --template-file ${template_path} --stack-name  CustomerCreatedConfigResourcesForControlTower --region ${region}
        aws cloudformation deploy --template-file ${template_path} --stack-name  CustomerCreatedConfigResourcesForControlTower --region ${region}
    fi
done
