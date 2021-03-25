#!/bin/bash -e

# constants
_BLUE='\033[1;34m'
_RED='\033[1;31m'
_NC='\033[0m'

_FORMAT="$0 resourceGroupName"

_BASENAME=aibBuiUserId

# arguments check
if (( $# != 1 )); then
    echo -e "${_RED}Missing arguments.${_NC}\nUse this format:\n\t${_BLUE}$_FORMAT${_NC}"
    exit 1
fi

imageResourceGroup=$1
subscriptionID=$(az account show --query id -o tsv)

echo "Preparing resource group $1 in subscription $subscriptionID"

# Check if an identity already exists
imgBuilderCliId=$(az identity list -g $imageResourceGroup --query "[?starts_with(name,'$_BASENAME') ].clientId" -o tsv)

if [ -z "$imgBuilderCliId" ]; then
    dateId=$(date +'%s')
    # create user assigned identity for image builder to access the storage account where the script is located
    identityName=$_BASENAME$dateId

    echo "Identity does not exist, creating a new identity with name $identityName"

    az identity create -g $imageResourceGroup -n $identityName

    # get identity id
    imgBuilderCliId=$(az identity show -g $imageResourceGroup -n $identityName --query clientId -o tsv)
else    
    identityName=$(az identity list -g $imageResourceGroup --query "[?starts_with(name,'$_BASENAME') ].name" -o tsv)

    echo "Identity already exists with name $identityName. Skipping creation."
    dateId=${identityName:${#_BASENAME}}
fi

# get the user identity URI, needed for the template
imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$imageResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

# download preconfigured role definition example
imageRoleDefName="Azure Image Builder Image Def"$dateId

#query to find the associated role Id
echo "run: az role definition list --query \"[?roleName=='$imageRoleDefName'].{scopes: assignableScopes, id: id} | [?scopes[?ends_with(@,'/resourceGroups/$imageResourceGroup')] ].id\" -o tsv"

roleId=$(az role definition list --query "[?roleName=='$imageRoleDefName'].{scopes: assignableScopes, id: id} | [?scopes[?ends_with(@,'/resourceGroups/$imageResourceGroup')] ].id" -o tsv)

if [[ -z "$roleId" ]] ; then
    echo "Creating role with name '$imageRoleDefName'"

    rm -f /tmp/aibRoleImageCreation.json
    curl https://raw.githubusercontent.com/azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json -o /tmp/aibRoleImageCreation.json

    # update the definition
    sed -i -e "s/<subscriptionID>/$subscriptionID/g" /tmp/aibRoleImageCreation.json
    sed -i -e "s/<rgName>/$imageResourceGroup/g" /tmp/aibRoleImageCreation.json
    sed -i -e "s/Azure Image Builder Service Image Creation Role/$imageRoleDefName/g" /tmp/aibRoleImageCreation.json

    # create role definitions
    roleId=$(az role definition create --role-definition /tmp/aibRoleImageCreation.json --query id -o tsv)
    
    echo -n "Wait until role definition lands "
    roleId=$(az role definition list --query "[?roleName=='$imageRoleDefName'].{scopes: assignableScopes, id: id} | [?scopes[?ends_with(@,'/resourceGroups/$imageResourceGroup')] ].id" -o tsv)    
    while [[ -z "$roleId" ]]; do
        echo -n "." && sleep 5
    done
    echo ""
else
    echo "Role '$imageRoleDefName' already exists. Skipping creation"
fi

assignmentId=$(az role assignment list -g $imageResourceGroup --query "[?roleDefinitionId=='$roleId'].id" -o tsv)

if [ -z $assignmentId ] ; then
    echo "Creating assignment"

    # grant role definition to the user assigned identity
    az role assignment create \
        --assignee $imgBuilderCliId \
        --role $roleId \
        --scope /subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup
else
    echo "Assignment already exists. Skipping creation"
fi