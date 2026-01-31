$groups = "consultants", "finance", "hr","it", "sales"

foreach ($group in $groups){
    Add-ADGroupMember `
  -Identity "l_fullAccess-$group-share" `
  -Members  "g_all_$group"
}