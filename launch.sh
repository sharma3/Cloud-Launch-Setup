#!/bin/bash

./cleanup.sh

#Declare the Array
declare -a instanceIDARR

#Launch instance

mapfile -t instanceIDARR = (aws ec2 run-instances --image-id ami-$1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' '| sed "s/InstanceId//g")

#Calling Instance Array
echo ${instanceIDARR[@]}

#ec2 wait command
aws ec2 wait instance-running --instance-ids ${instanceIDARR[@]}
echo "Instances are Running"


