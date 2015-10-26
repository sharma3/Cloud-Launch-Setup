#!/bin/bash

./cleanup.sh

#Declare the Array
declare -a instanceIDARR

#Launch instance

mapfile -t instanceIDARR < <(aws ec2 run-instances --image-id ami-$1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

#Calling Instance Array
echo ${instanceIDARR[@]}

#ec2 wait command
aws ec2 wait instance-running --instance-ids ${instanceIDARR[@]}
echo "Instances are Running"

#Load Balancer
ELBURL=(`aws elb create-load-balancer --load-balancer-name $8 --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $6 --security-groups $5 --output=text`); echo $ELBURL
echo -e "\nFinished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Register Instance to load balancer
aws elb register-instances-with-load-balancer --load-balancer-name $8 --instances ${instanceIDARR[@]}

#Health Check of load balancer
aws elb configure-health-check --load-balancer-name $8 --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
echo -e "\nWaiting an additional 180 sec - before opening the load balancer in a web browser"
for i in {0..180}; do echo -ne '.'; sleep 1;done

#Create Launch Configuration
aws autoscaling create-launch-configuration --launch-configuration-name $9 --image-id ami-$1 --instance-type $3 --key-name $4 --security-groups $5 --iam-instance-profile $7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh
