# TODO idempotency
# Set-PSDebug -Trace 1

$this_ip=$Args[0]
$master_ip=$Args[1]
$project=$Args[2]
$newname=$Args[3]

# Configure network interface
# New-NetIPAddress -InterfaceAlias "Ethernet 2" $this_ip -PrefixLength 24

# Rename computer
Rename-Computer -ComputerName . -NewName $newname

# Configure firewall
netsh advfirewall set allprofiles state off

# Configure Docker daemon
Stop-Service docker
Set-Content -Path $env:ProgramData\docker\config\daemon.json -Value '{
  "registry-mirrors": [
    "http://172.22.101.100:4000/"
  ],
  "insecure-registries": [
    "172.22.101.100:5000"
  ],
  "debug": true
}'

# Get registration token
$id=Invoke-RestMethod http://$master_ip/v2-beta/project?name=$project -Headers @{"accept"="application/json"} | Select-Object -expand data | Select-Object -ExpandProperty id
$regUrl = Invoke-RestMethod -Uri http://$master_ip/v2-beta/projects/$id/registrationtoken -Body @{"type"="registrationToken"} -ContentType application/json -Headers @{"accept"="application/json"} | Select-Object -expand data | Select-Object -ExpandProperty registrationUrl | Select-Object -First 1

# Download agent
New-Item -Path 'C:\Program Files\rancher' -Type Directory
Invoke-WebRequest -UseBasicParsing 'https://github.com/LLParse/agent/releases/download/windows/agent.exe' -OutFile 'C:\Program Files\rancher\agent.exe'

# Register agent
. "C:\Program Files\rancher\agent.exe" --register-service $regUrl

shutdown /r /t 0

# Start services
# Start-Service docker
# Start-Service rancher-agent
