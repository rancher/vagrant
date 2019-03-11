#!/bin/bash

for i in $(VBoxManage list vms | awk '{print $2}'); do
	echo "$i"
	VBoxManage controlvm $i poweroff
        VBoxManage unregistervm $i --delete
done
