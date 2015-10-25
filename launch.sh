#!/bin/bash
aws ec2 run-instances --image-id ami-$1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-profile $7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh --debug


sleep 180

