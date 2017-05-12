#	curl -XPOST -H 'Content-Type: application/json' -H 'accept: application/json' -d '{"type":"registrationToken"}' 'http://172.22.101.105:8080/v1/projects/1a5/registrationtoken'
while true;do
wget -T 5 -c http://172.22.101.100:8080 && break
sleep 5
done


docker run -v /tmp:/tmp --rm appropriate/curl -XPOST -H 'Content-Type: application/json' -H 'accept: application/json' -d '{"type":"registrationToken"}' 'http://172.22.101.100:8080/v1/projects/1a5/registrationtoken'
docker run -v /tmp:/tmp --rm appropriate/curl http://172.22.101.100:8080/v1/projects/1a5/registrationtokens | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'id'\042/){print $(i+1)}}}' | tr -d '"' | sed -n 1p >/tmp/rancher.txt
ENVID=$(cat /tmp/rancher.txt)
echo "Adding host to Rancher Server"
echo "Processing command...$ENVID"
docker run -v /tmp:/tmp --rm appropriate/curl http://172.22.101.100:8080/v1/projects/1a5/registrationtokens/$ENVID | grep -Eo '[^,]*' | grep -E 'command' | awk '{gsub("command\":", ""); gsub("\"", "");print}' > /tmp/script.sh
chmod +x /tmp/script.sh
/tmp/script.sh

     