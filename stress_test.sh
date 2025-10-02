#!/bin/bash

echo "Getting instance information from Auto Scaling Group..."

# Check if cctb.pem exists
if [ ! -f "cctb.pem" ]; then
    echo "Error: cctb.pem not found. Make sure you've run deploy.sh first."
    exit 1
fi

# Get instance ID from Auto Scaling Group
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text 2>/dev/null)

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "No instances found in the Auto Scaling Group"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Get public IP address
echo "Getting public IP address..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)

if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
    echo "No public IP found for instance $INSTANCE_ID"
    exit 1
fi

echo "Public IP: $PUBLIC_IP"

# Ensure proper permissions on key file
chmod 400 cctb.pem

# SSH into the instance and run stress test
echo "Running stress test on the instance..."
ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "sudo yum install -y stress && stress --cpu 6 --timeout 120"