az role assignment delete -g $imageResourceGroup

az role definition list --query "[*].{scopes: assignableScopes, roleName: roleName} | [?scopes[?ends_with(@,'/resourceGroups/$imageResourceGroup')] ].roleName" | xargs -I{} az role definition delete -g $imageResourceGroup --name '{}'

az identity list -g $imageResourceGroup --query "[?starts_with(name,'$_BASENAME') ].id" -o tsv | xargs -I{} az identity delete -g $imageResourceGroup --ids {}
