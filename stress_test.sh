#!/bin/bash

echo "Getting instance information from Auto Scaling Group..."

# Check if cctb.pem exists
if [ ! -f "cctb.pem" ]; then
    echo "Error: cctb.pem not found. Make sure you've run deploy.sh first."
    exit 1
fi

# Get instance IDs from Auto Scaling Group
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text 2>/dev/null)

if [ "$INSTANCE_IDS" == "None" ] || [ -z "$INSTANCE_IDS" ]; then
    echo "No instances found in the Auto Scaling Group"
    exit 1
fi

echo "Instance IDs: $INSTANCE_IDS"

# Loop through instances to find one with a public IP
for INSTANCE_ID in $INSTANCE_IDS; do
    echo "Checking instance $INSTANCE_ID for public IP..."
    
    # Get public IP address
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null)
    
    if [ "$PUBLIC_IP" != "None" ] && [ ! -z "$PUBLIC_IP" ]; then
        echo "Found instance with public IP:"
        echo "Instance ID: $INSTANCE_ID"
        echo "Public IP: $PUBLIC_IP"
        
        # Show security group information
        echo "Checking security group settings..."
        SG_IDS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text 2>/dev/null)
        echo "Security Group IDs: $SG_IDS"
        
        # Test direct access to the application
        echo "Testing direct access to Django application on port 8000..."
        curl -v http://$PUBLIC_IP:8000
        
        # Show log file from instance
        echo "Checking application logs..."
        chmod 400 cctb.pem
        ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "tail -n 20 /home/ec2-user/django.log"
        
        # Run stress test
        echo "Running stress test on the instance..."
        ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "sudo yum install -y stress && stress --cpu 6 --timeout 120"
        exit 0
    fi
done

echo "No instances with public IP found"
exit 1