# Management of existing AWS Config resources before account enrolment in AWS CT

**Disclaimers** :
- this project was done for personal convenience and will no be supported
- you should understand what it does before using it
- use it at your own risk

## Objectives

We wanted to secure and speed up the process of enrolling AWS accounts in AWS Control Tower when there were existing AWS Config ressources.

The `config_for_ct.sh` script automates the actions mentionned in the AWS Documentation : [Enroll accounts that have existing AWS Config resources](https://docs.aws.amazon.com/controltower/latest/userguide/existing-config-resources.html) (based on the 2023/07/27 version). 

Obviously, steps to open an support case and enrolling the account are not managet by this script.

The `create_ct_role.sh` script creates the mandatory role for AWS Control Tower management.

## Requirements

In order to use this project, you need :

- a bash terminal
- AWS CLI v2 installed
- jq installed (json query)
- AWS CLI credentials for a user/role with the right permissions on the account (see "Launch" section of each script). TIPS : may be obtained using IAM Identity center

## Config for CT usage

The configuration for this script is done by setting parameter values inside it (not the best way but I did it fast ;) )

### Parameters:

- PROTECTED_ACCOUNTS : list of account IDs this script must not run on : if, by mistake, you try to run the script on this account, it should stop and exit. This is a security lock and you should list the management account and security accounts (even if they should already be protected by SCPs)
- ORGANIZATION_ID : ID of the AWS Organization you are working on
- LOGGING_ACCOUNT : ID of the LogArchive Account managed by AWS Control Tower
- AUDIT_ACCOUNT : ID of the Audit Account managed by AWS Control Tower
- CURRENT_REGION : list of governed regions : Home region + all the additional regions
- HOME_REGION : Home region of your AWS Control Tower implementation

### Launch

AWS CLI configuration : set you terminal with credentials on the account you are about to enroll

Get into the root directory of this project and simply launch the script without any argument.

## Create CT role usage

There is no configuration for this script.

In order to work, the script will use the AWS Managed role `OrganizationAccountAccessRole` automatically created by AWS Organization.
If the script does not work, you should check this.

### Launch

AWS CLI configuration : set you terminal with credentials on the Management account of the organization.

Get into the root directory of this project and launch the script with the ID of the account to be enroled as argument.

ex : `./create_ct_role.sh 123456789123`
