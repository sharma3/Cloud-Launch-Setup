#!/bin/bash

./cleanup.sh

#Declare the Array
declare -a instanceIDARR
declare -a autoscaleARNARR

#Create RDS Db instance
aws rds create-db-instance --db-instance-identifier jaysharma-rds --allocated-storage 5 --db-instance-class db.t1.micro --engine mysql --master-username JaySharma --master-user-password sharma1234 --vpc-security-group-ids sg-56ebff31 --db-subnet-group-name jaysharmadb-subnet --db-name datadb 

#db instance wait
aws rds wait db-instance-available --db-instance-identifier JaySharma-RDS
echo "db instance is created"

#Create Read Replica
aws rds create-db-instance-read-replica --db-instance-identifier jaysharma-readreplica --source-db-instance-identifier jaysharma-rds


#Launch instance
mapfile -t instanceIDARR < <(aws ec2 run-instances --image-id ami-$1 --count $2 --instance-type $3 --key-name $4 --security-group-ids $5 --subnet-id $6 --associate-public-ip-address --iam-instance-profile Name=$7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

#Calling Instance Array
echo ${instanceIDARR[@]}

#ec2 wait command
aws ec2 wait instance-running --instance-ids ${instanceIDARR[@]}
echo "Instances are Running"

#Load Balancer
ELBURL=(`aws elb create-load-balancer --load-balancer-name jaysharma-elb --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $6 --security-groups $5 --output=text`); echo $ELBURL
echo -e "\nFinished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Register Instance to load balancer
aws elb register-instances-with-load-balancer --load-balancer-name jaysharma-elb --instances ${instanceIDARR[@]}

#Health Check of load balancer
aws elb configure-health-check --load-balancer-name jaysharma-elb --health-check Target=HTTP:80/index.php,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3
echo -e "\nWaiting an additional 180 sec - before opening the load balancer in a web browser"
for i in {0..180}; do echo -ne '.'; sleep 1;done

#Create Launch Configuration
aws autoscaling create-launch-configuration --launch-configuration-name jaysharma-lcong --image-id ami-$1 --instance-type $3 --key-name $4 --security-groups $5 --iam-instance-profile $7 --user-data file://~/Documents/ITMO-544-A20344475-Enviornment-Setup/install-env.sh

#Create Auto Scaling
mapfile -t autoscaleARNARR < <(aws autoscaling create-auto-scaling-group --auto-scaling-group-name jaysharma-autoscale --launch-configuration-name jaysharma-lcong --load-balancer-names jaysharma-elb --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $6 --output table | grep AutoScalingGroupARN | sed "s/|//g" | tr -d ' ' | sed "s/AutoScalingGroupARN//g")

echo ${autoscaleARNARR[@]}

#CloudWatch Alarm for SNS
 
topicArn= ('aws sns create-topic --name snsCloudWatch')

echo $topicArn

aws sns set-topic-attributes --topic-arn $topicArn --attribute-name SNS-matricWatch

aws sns subscribe --topic-arn $topicArn --protocol sms --notification-endpoint $8

aws autoscaling put-notification-configuration --auto-scaling-group-name jaysharma-autoscale --topic-arn $topicArn --notification-types autoscaling:EC2_LAUNCH

aws autoscaling put-notification-configuration --auto-scaling-group-name jaysharma-autoscale --topic-arn $topicArn --notification-types autoscaling:EC2_TERMINATE

aws cloudwatch put-metric-alarm --alarm-name UPSNS --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 1 --dimensions "Name=AutoScalingGroupName,Value=jaysharma-autoscale" --unit Percent --alarm-actions $topicArn


aws cloudwatch put-metric-alarm --alarm-name DOWNSNS --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 10 --comparison-operator LessThanOrEqualToThreshold  --evaluation-periods 1 --dimensions "Name=AutoScalingGroupName,Value=jaysharma-autoscale" --unit Percent --alarm-actions $topicArn



#Create cloud watch for 30 threshold
aws cloudwatch put-metric-alarm --alarm-name JaySharma-alarm --metric-name CPUUtilization --namespace AWS/ELB --statistic Average --period 300 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold  --dimensions  Name=AutoScaling,Value=jaysharma-autoscale --evaluation-periods 2 --alarm-actions ${autoscaleARNARR[@]} --unit Percent

#Create cloud watch for 10 threshold
aws cloudwatch put-metric-alarm --alarm-name JaySharma-alarm1 --metric-name CPUUtilization --namespace AWS/ELB --statistic Average --period 300 --threshold 10 --comparison-operator LessThanOrEqualToThreshold  --dimensions  Name=AutoScaling,Value=jaysharma-autoscale --evaluation-periods 2 --alarm-actions ${autoscaleARNARR[@]} --unit Percent


#Open Browser
firefox $ELBURL/index.php &
#chromium-browser $ELBURL &
export ELBURL
