New-NetIPAddress -InterfaceAlias "Ethernet 2" $Args[0] -PrefixLength 24
$ip=$Args[1]
$id=Invoke-RestMethod http://$ip/v2-beta/project?name=windows -Headers @{"accept"="application/json"} | Select-Object -expand data | Select-Object -ExpandProperty id
$regUrl = Invoke-RestMethod -Uri http://$ip/v2-beta/projects/$id/registrationtoken -Body @{"type"="registrationToken"} -ContentType application/json -Headers @{"accept"="application/json"} |Select-Object -expand data | Select-Object -ExpandProperty registrationUrl | Select-Object -First 1
. "C:\Program Files\rancher\agent.exe" --register-service $regUrl
stop-service docker
rename-computer -computername . -newname $Args[2]
shutdown /r /t 0
