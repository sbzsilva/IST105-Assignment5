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
        
        chmod 400 cctb.pem
        
        # Install stress using a reliable method
        echo "Installing stress tool..."
        ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP << 'EOF'
# Install dependencies
sudo yum update -y
sudo yum install -y gcc make wget

# Download and compile stress from a reliable source
cd /tmp
rm -rf stress-*
wget http://ftp.debian.org/debian/pool/main/s/stress/stress_1.0.4.orig.tar.gz
tar xzf stress_1.0.4.orig.tar.gz
cd stress-1.0.4
./configure
make
sudo make install

# Verify installation
echo "Stress installation check:"
which stress || echo "Stress not in PATH"
/usr/local/bin/stress --version || echo "Cannot run stress"
EOF

        # Verify stress is installed and run the test FOREGROUND
        echo "Starting 10-minute stress test..."
        echo "Expected: CPU should show ~200% usage, load average ~4.0"
        echo "Starting at: $(date)"
        
        # Run stress test in FOREGROUND so we can see if it works
        ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "/usr/local/bin/stress --cpu 4 --timeout 600" &
        STRESS_PID=$!
        
        # Monitor every 10 seconds for the first minute to verify it's working
        for i in {1..6}; do
            sleep 10
            echo "Progress: $((i * 10)) seconds / 600 seconds"
            
            echo "Current CPU usage:"
            ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "top -bn1 | grep 'Cpu(s)' | head -1"
            
            echo "Load average:"
            ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "uptime"
            
            echo "Running processes (stress should appear):"
            ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "ps aux | grep stress | grep -v grep"
            
            echo "Application health:"
            ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "curl -s http://localhost:8000 > /dev/null && echo '✓ OK' || echo '✗ FAILED'"
            echo "---"
        done
        
        # Wait for stress test to complete
        echo "Waiting for stress test to complete..."
        wait $STRESS_PID
        
        echo "Stress test finished at: $(date)"
        echo "Final system status:"
        ssh -o StrictHostKeyChecking=no -i cctb.pem ec2-user@$PUBLIC_IP "uptime; free -h"
        
        exit 0
    fi
done

echo "No instances with public IP found"
exit 1