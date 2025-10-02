#!/bin/bash

echo "Starting cleanup process..."

# Function to check if AWS command succeeded
check_aws_result() {
    if [ $? -ne 0 ]; then
        echo "Warning: $1"
    fi
}

# Delete Load Balancer first
echo "Deleting Load Balancer..."
LB_ARN=$(aws elbv2 describe-load-balancers --names treasure-hunt-lb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ ! -z "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
    check_aws_result "Issue deleting load balancer"
    
    # Wait for LB to be deleted
    echo "Waiting for Load Balancer to be deleted..."
    sleep 30
else
    echo "Load Balancer not found"
fi

# Delete Auto Scaling Group
echo "Deleting Auto Scaling Group..."
ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg 2>/dev/null || echo "NOT_FOUND")
if [[ $ASG_EXISTS != *"NOT_FOUND"* ]]; then
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name treasure-hunt-asg --force-delete
    check_aws_result "Issue deleting auto scaling group"
    
    # Wait for ASG to be deleted
    echo "Waiting for Auto Scaling Group to be deleted..."
    sleep 60
else
    echo "Auto Scaling Group not found"
fi

# Delete Target Group
echo "Deleting Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names treasure-hunt-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ ! -z "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    aws elbv2 delete-target-group --target-group-arn $TG_ARN
    check_aws_result "Issue deleting target group"
else
    echo "Target Group not found"
fi

# Delete Launch Template
echo "Deleting Launch Template..."
LT_ID=$(aws ec2 describe-launch-templates --launch-template-names treasure-hunt-lt --query 'LaunchTemplates[0].LaunchTemplateId' --output text 2>/dev/null)
if [ ! -z "$LT_ID" ] && [ "$LT_ID" != "None" ]; then
    aws ec2 delete-launch-template --launch-template-id $LT_ID
    check_aws_result "Issue deleting launch template"
else
    echo "Launch Template not found"
fi

# Delete Security Groups
echo "Deleting Security Groups..."
INSTANCE_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=treasure-hunt-instance-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ ! -z "$INSTANCE_SG_ID" ] && [ "$INSTANCE_SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $INSTANCE_SG_ID 2>/dev/null
    check_aws_result "Issue deleting instance security group"
else
    echo "Instance Security Group not found"
fi

LB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=treasure-hunt-lb-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ ! -z "$LB_SG_ID" ] && [ "$LB_SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $LB_SG_ID 2>/dev/null
    check_aws_result "Issue deleting load balancer security group"
else
    echo "Load Balancer Security Group not found"
fi

# Detach and Delete Internet Gateway
echo "Deleting Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=treasure-hunt-igw" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=treasure-hunt-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "None" ] && [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID 2>/dev/null
    check_aws_result "Issue detaching internet gateway"
    
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID 2>/dev/null
    check_aws_result "Issue deleting internet gateway"
else
    echo "Internet Gateway not found or VPC not found"
fi

# Delete Subnets
echo "Deleting Subnets..."
SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=treasure-hunt-subnet-1" --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
if [ ! -z "$SUBNET1_ID" ] && [ "$SUBNET1_ID" != "None" ]; then
    aws ec2 delete-subnet --subnet-id $SUBNET1_ID 2>/dev/null
    check_aws_result "Issue deleting subnet 1"
else
    echo "Subnet 1 not found"
fi

SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=treasure-hunt-subnet-2" --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
if [ ! -z "$SUBNET2_ID" ] && [ "$SUBNET2_ID" != "None" ]; then
    aws ec2 delete-subnet --subnet-id $SUBNET2_ID 2>/dev/null
    check_aws_result "Issue deleting subnet 2"
else
    echo "Subnet 2 not found"
fi

# Delete Route Table
echo "Deleting Route Table..."
RT_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=treasure-hunt-rt" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
if [ ! -z "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
    aws ec2 delete-route-table --route-table-id $RT_ID 2>/dev/null
    check_aws_result "Issue deleting route table"
else
    echo "Route Table not found"
fi

# Delete VPC
echo "Deleting VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=treasure-hunt-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    aws ec2 delete-vpc --vpc-id $VPC_ID 2>/dev/null
    check_aws_result "Issue deleting VPC"
else
    echo "VPC not found"
fi

# Delete Key Pair
echo "Deleting Key Pair..."
KEY_EXISTS=$(aws ec2 describe-key-pairs --key-names cctb 2>/dev/null || echo "NOT_FOUND")
if [[ $KEY_EXISTS != *"NOT_FOUND"* ]]; then
    aws ec2 delete-key-pair --key-name cctb 2>/dev/null
    check_aws_result "Issue deleting key pair"
    
    # Remove local key file if it exists
    if [ -f "cctb.pem" ]; then
        rm cctb.pem
        echo "Local key file cctb.pem removed"
    fi
else
    echo "Key Pair not found"
fi

echo "Cleanup complete!"