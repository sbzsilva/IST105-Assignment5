#!/bin/bash
# Delete Auto Scaling Group
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name treasure-hunt-asg --force-delete

# Delete Load Balancer
LB_ARN=$(aws elbv2 describe-load-balancers --names treasure-hunt-lb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN

# Delete Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names treasure-hunt-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 delete-target-group --target-group-arn $TG_ARN

# Delete Launch Template
aws ec2 delete-launch-template --launch-template-name treasure-hunt-lt


# Delete Security Groups
aws ec2 delete-security-group --group-id treasure-hunt-instance-sg
aws ec2 delete-security-group --group-id treasure-hunt-lb-sg

# Delete Subnets
aws ec2 delete-subnet --subnet-id treasure-hunt-subnet-1
aws ec2 delete-subnet --subnet-id treasure-hunt-subnet-2

# Delete Route Table
aws ec2 delete-route-table --route-table-id treasure-hunt-rt

# Detach and Delete Internet Gateway
aws ec2 detach-internet-gateway --internet-gateway-id treasure-hunt-igw --vpc-id treasure-hunt-vpc
aws ec2 delete-internet-gateway --internet-gateway-id treasure-hunt-igw

# Delete VPC
aws ec2 delete-vpc --vpc-id treasure-hunt-vpc

echo "Cleanup complete!"