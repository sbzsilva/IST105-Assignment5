#!/bin/bash

# Configuration - Update these values
KEY_NAME="cctb"
GITHUB_REPO="https://github.com/sbzsilva/IST105-Assignment5.git"
AWS_REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
MIN_SIZE=1
MAX_SIZE=5
DESIRED_CAPACITY=1

# Function to check if AWS command succeeded
check_aws_result() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
check_aws_result "Failed to create VPC"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=treasure-hunt-vpc

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
check_aws_result "Failed to create Internet Gateway"
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=treasure-hunt-igw
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create Subnets
echo "Creating Subnets..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a --query 'Subnet.SubnetId' --output text)
check_aws_result "Failed to create subnet 1"
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b --query 'Subnet.SubnetId' --output text)
check_aws_result "Failed to create subnet 2"
aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value=treasure-hunt-subnet-1
aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value=treasure-hunt-subnet-2

# Create Route Table
echo "Creating Route Table..."
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
check_aws_result "Failed to create route table"
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=treasure-hunt-rt
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET1_ID
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET2_ID
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Create Security Groups
echo "Creating Security Groups..."
LB_SG_ID=$(aws ec2 create-security-group --group-name treasure-hunt-lb-sg --description "Security group for load balancer" --vpc-id $VPC_ID --query 'GroupId' --output text)
check_aws_result "Failed to create load balancer security group"
aws ec2 authorize-security-group-ingress --group-id $LB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

INSTANCE_SG_ID=$(aws ec2 create-security-group --group-name treasure-hunt-instance-sg --description "Security group for EC2 instances" --vpc-id $VPC_ID --query 'GroupId' --output text)
check_aws_result "Failed to create instance security group"
aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 8000 --source-group $LB_SG_ID

# Create the key pair if it doesn't exist
echo "Checking if key pair exists..."
KEY_CHECK=$(aws ec2 describe-key-pairs --key-names $KEY_NAME 2>&1 || echo "NOT_FOUND")

if [[ $KEY_CHECK == *"NOT_FOUND"* ]]; then
    echo "Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "Key pair created and saved to ${KEY_NAME}.pem"
else
    echo "Key pair $KEY_NAME already exists"
fi

# Create user data script
cat > /tmp/userdata.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y git python3 python3-pip
cd /home/ec2-user
git clone https://github.com/sbzsilva/IST105-Assignment5.git assignment5
cd assignment5
pip3 install -r requirements.txt
export DJANGO_SETTINGS_MODULE=assignment5.settings
python3 manage.py migrate
python3 manage.py collectstatic --noinput
python3 manage.py runserver 0.0.0.0:8000 > /home/ec2-user/django.log 2>&1 &
echo "Django application started" >> /home/ec2-user/deployment.log
EOF

# Base64 encode the user data script (compatible with all systems)
USER_DATA=$(base64 /tmp/userdata.sh | tr -d '\n')

# Create Launch Template with improved user data script
echo "Creating Launch Template..."
LT_ID=$(aws ec2 create-launch-template --launch-template-name treasure-hunt-lt --launch-template-data '{
  "ImageId": "ami-09d3b3274b6c5d4aa",
  "InstanceType": "'"$INSTANCE_TYPE"'",
  "KeyName": "'"$KEY_NAME"'",
  "SecurityGroupIds": ["'"$INSTANCE_SG_ID"'"],
  "UserData": "'"$USER_DATA"'"
}' --query 'LaunchTemplate.LaunchTemplateId' --output text)
check_aws_result "Failed to create launch template"

# Create Target Group
echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group --name treasure-hunt-tg --protocol HTTP --port 8000 --vpc-id $VPC_ID --health-check-path=/ --query 'TargetGroups[0].TargetGroupArn' --output text)
check_aws_result "Failed to create target group"

# Set the load balancing algorithm to Least outstanding requests
echo "Setting load balancing algorithm to Least outstanding requests..."
aws elbv2 modify-target-group-attributes \
    --target-group-arn $TG_ARN \
    --attributes Key=load_balancing.algorithm.type,Value=least_outstanding_requests

# Create Load Balancer
echo "Creating Load Balancer..."
LB_ARN=$(aws elbv2 create-load-balancer --name treasure-hunt-lb --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $LB_SG_ID --query 'LoadBalancers[0].LoadBalancerArn' --output text)
check_aws_result "Failed to create load balancer"
LB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)

# Create Listener
echo "Creating Listener..."
aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN
check_aws_result "Failed to create listener"

# Create Auto Scaling Group
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name treasure-hunt-asg \
  --launch-template LaunchTemplateId=$LT_ID,Version='$Latest' \
  --min-size $MIN_SIZE \
  --max-size $MAX_SIZE \
  --desired-capacity $DESIRED_CAPACITY \
  --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
  --target-group-arns $TG_ARN \
  --health-check-type ELB \
  --health-check-grace-period 300
check_aws_result "Failed to create auto scaling group"

# Give the ASG a moment to create
sleep 10

# Check if ASG was created successfully
ASG_EXISTS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names treasure-hunt-asg 2>&1 || echo "NOT_FOUND")

if [[ $ASG_EXISTS != *"NOT_FOUND"* ]]; then
    # Create Scaling Policy
    echo "Creating Scaling Policy..."
    aws autoscaling put-scaling-policy \
      --policy-name cpu-scaling-policy \
      --auto-scaling-group-name treasure-hunt-asg \
      --policy-type TargetTrackingScaling \
      --target-tracking-configuration '{
        "PredefinedMetricSpecification": {
          "PredefinedMetricType": "ASGAverageCPUUtilization"
        },
        "TargetValue": 10,
        "DisableScaleIn": false
      }'
    check_aws_result "Failed to create scaling policy"
else
    echo "Auto Scaling Group was not created successfully. Skipping scaling policy creation."
fi

# Clean up temporary file
rm /tmp/userdata.sh

# Output results
echo "Deployment complete!"
echo "Load Balancer DNS: http://$LB_DNS"
echo "Access your application at: http://$LB_DNS"