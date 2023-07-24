#!bash
target_account_id=$1

[ -z "$target_account_id" ] && echo "Please provide target account id" && exit 1

orga_role=OrganizationAccountAccessRole
ct_role=AWSControlTowerExecution
target_role=$orga_role

local_account_id=$(aws sts get-caller-identity | jq -r '.Account')

export AWS_PAGER=""
local_access_key_id=$AWS_ACCESS_KEY_ID
local_secret_access_key=$AWS_SECRET_ACCESS_KEY
local_session_token=$AWS_SESSION_TOKEN

function assume {
    if [ "$1" == "local" ]; then
        export AWS_ACCESS_KEY_ID=$local_access_key_id
        export AWS_SECRET_ACCESS_KEY=$local_secret_access_key
        export AWS_SESSION_TOKEN=$local_session_token
    elif [ "$1" == "target" ]; then
        export AWS_ACCESS_KEY_ID=$target_access_key_id
        export AWS_SECRET_ACCESS_KEY=$target_secret_access_key
        export AWS_SESSION_TOKEN=$target_session_token
    fi
}

function display_credentials {
    echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    echo AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
}

# aws sts get-caller-identity
target_credentials=$(aws sts assume-role --role-arn "arn:aws:iam::${target_account_id}:role/${target_role}" --role-session-name "target" | jq -r '.Credentials')
export target_access_key_id=$(echo $target_credentials | jq -r '.AccessKeyId')
export target_secret_access_key=$(echo $target_credentials | jq -r '.SecretAccessKey')
export target_session_token=$(echo $target_credentials | jq -r '.SessionToken')

assume target
aws sts get-caller-identity ; assumed=$?
if [ $assumed -eq 0 ]; then
    tmp=$(mktemp)
    sed 's/local_account_id/'$local_account_id'/g' role/assume_role_policy.json > $tmp
    aws iam create-role --role-name $ct_role --assume-role-policy-document file://$tmp
    aws iam attach-role-policy --role-name $ct_role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess > /dev/null
fi
