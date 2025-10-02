#!/bin/bash

# Delete Auto Scaling Group
echo "Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name treasure-hunt-asg --force-delete

# Wait a moment for ASG to delete
sleep 10

# Delete Load Balancer
echo "Deleting Load Balancer..."
LB_ARN=$(aws elbv2 describe-load-balancers --names treasure-hunt-lb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ ! -z "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
fi

# Delete Target Group
echo "Deleting Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names treasure-hunt-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ ! -z "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    aws elbv2 delete-target-group --target-group-arn $TG_ARN
fi

# Delete Launch Template
echo "Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name treasure-hunt-lt

# Delete Security Groups
echo "Deleting Security Groups..."
aws ec2 delete-security-group --group-id treasure-hunt-instance-sg 2>/dev/null || echo "Could not delete instance security group"
aws ec2 delete-security-group --group-id treasure-hunt-lb-sg 2>/dev/null || echo "Could not delete load balancer security group"

# Delete Subnets
echo "Deleting Subnets..."
aws ec2 delete-subnet --subnet-id treasure-hunt-subnet-1 2>/dev/null || echo "Could not delete subnet 1"
aws ec2 delete-subnet --subnet-id treasure-hunt-subnet-2 2>/dev/null || echo "Could not delete subnet 2"

# Delete Route Table
echo "Deleting Route Table..."
aws ec2 delete-route-table --route-table-id treasure-hunt-rt 2>/dev/null || echo "Could not delete route table"

# Detach and Delete Internet Gateway
echo "Deleting Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=treasure-hunt-igw" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null)
if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id treasure-hunt-vpc 2>/dev/null || echo "Could not detach internet gateway"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID 2>/dev/null || echo "Could not delete internet gateway"
fi

# Delete VPC
echo "Deleting VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=treasure-hunt-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    aws ec2 delete-vpc --vpc-id $VPC_ID 2>/dev/null || echo "Could not delete VPC"
fi

# Delete Key Pair
echo "Deleting Key Pair..."
aws ec2 delete-key-pair --key-name cctb 2>/dev/null || echo "Could not delete key pair"

echo "Cleanup complete!"