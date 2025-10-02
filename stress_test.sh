#!/bin/bash
echo "Getting instance information from Auto Scaling Group..."
# Get instance ID from Auto Scaling Group
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

if [ "$INSTANCE_ID" == "None" ]; then
    echo "No instances found in the Auto Scaling Group"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Get public IP address
echo "Getting public IP address..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

if [ "$PUBLIC_IP" == "None" ]; then
    echo "No public IP found for instance $INSTANCE_ID"
    exit 1
fi

echo "Public IP: $PUBLIC_IP"

# SSH into the instance and run stress test
echo "Running stress test on the instance..."
ssh -i your-key-pair.pem ec2-user@$PUBLIC_IP "sudo yum install -y stress && stress --cpu 6 --timeout 120"