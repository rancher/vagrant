Set-PSDebug -Trace 1
New-NetIPAddress -InterfaceAlias "Ethernet 2" $Args[0] -PrefixLength 24
$ip=$Args[1]
$project=$Args[2]
$id=Invoke-RestMethod http://$ip/v2-beta/project?name=$project -Headers @{"accept"="application/json"} | Select-Object -expand data | Select-Object -ExpandProperty id
$regUrl = Invoke-RestMethod -Uri http://$ip/v2-beta/projects/$id/registrationtoken -Body @{"type"="registrationToken"} -ContentType application/json -Headers @{"accept"="application/json"} |Select-Object -expand data | Select-Object -ExpandProperty registrationUrl | Select-Object -First 1
. "C:\Program Files\rancher\agent.exe" --register-service $regUrl

Stop-Service docker
Set-Content -Path $env:ProgramData\docker\config\daemon.json -Value '{
  "registry-mirrors": [
    "172.22.101.100:4000"
  ],
  "insecure-registries": [
    "172.22.101.100:5000"
  ],
  "debug": true
}'

rename-computer -computername . -newname $Args[3]
# node.vm.provision "shell", inline: "netsh advfirewall firewall add rule name='Swarm Peer' dir=in action=allow protocol=tcp localport=2377; netsh advfirewall firewall add rule name='Swarm Network Discovery TCP' dir=in action=allow protocol=tcp localport=7946; netsh advfirewall firewall add rule name='Swarm Network Discovery UDP' dir=in action=allow protocol=udp localport=7946; netsh advfirewall firewall add rule name='Swarm Overlay Network' dir=in action=allow protocol=udp localport=4789"
# netsh advfirewall set allprofiles state off

shutdown /r /t 0
