#!/bin/bash
# Get instance ID from Auto Scaling Group
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

# Get public IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# SSH into the instance and run stress test
ssh -i your-key-pair.pem ec2-user@$PUBLIC_IP "sudo yum install -y stress && stress --cpu 6 --timeout 120"