$time = (Get-TimeZone).Id
$languages = Get-WinUserLanguageList

if ($time -ne "W. Europe Standard Time") {
    Set-TimeZone -Id "W. Europe Standard Time"
}

if ($languages.LanguageTag -notcontains "nb-NO") {
    Set-WinUserLanguageList -LanguageList "nb-NO" -Force
}