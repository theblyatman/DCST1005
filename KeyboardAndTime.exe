time=(Get-TimeZone).id
keyboard=(Get-WinUserLanguageList).LanguageTag

if ($time -ne "W. Europe Standard Time") {
    Set-TimeZone -Id "W. Europe Standard Time"
}

if ($keyboard -notcontains "nb-NO") {
    Set-WinUserLanguageList "nb-NO" -Force
}
