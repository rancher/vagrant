#	curl -XPOST -H 'Content-Type: application/json' -H 'accept: application/json' -d '{"type":"registrationToken"}' 'http://172.22.101.105:8080/v1/projects/1a5/registrationtoken'
	
    ENVID=$(curl http://172.22.101.105:8080/v1/projects/1a5/registrationtokens | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'id'\042/){print $(i+1)}}}' | tr -d '"' | sed -n 1p)
	echo "Adding host to Rancher Server"
	echo "Processing command...$ENVID"
    curl http://172.22.101.105:8080/v1/projects/1a5/registrationtokens/$ENVID | grep -Eo '[^,]*' | grep -E 'command' | awk '{gsub("command\":", ""); gsub("\"", "");print}' | sh