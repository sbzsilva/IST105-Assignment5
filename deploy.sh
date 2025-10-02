#!/bin/bash

# Configuration - Update these values
KEY_NAME="your-key-pair-name"
GITHUB_REPO="https://github.com/YOUR_USERNAME/IST105-Assignment5.git"
AWS_REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
MIN_SIZE=1
MAX_SIZE=5
DESIRED_CAPACITY=1

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=treasure-hunt-vpc

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=treasure-hunt-igw
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Create Subnets
echo "Creating Subnets..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a --query 'Subnet.SubnetId' --output text)
SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value=treasure-hunt-subnet-1
aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value=treasure-hunt-subnet-2

# Create Route Table
echo "Creating Route Table..."
RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=treasure-hunt-rt
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET1_ID
aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUBNET2_ID
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Create Security Groups
echo "Creating Security Groups..."
LB_SG_ID=$(aws ec2 create-security-group --group-name treasure-hunt-lb-sg --description "Security group for load balancer" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $LB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

INSTANCE_SG_ID=$(aws ec2 create-security-group --group-name treasure-hunt-instance-sg --description "Security group for EC2 instances" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $INSTANCE_SG_ID --protocol tcp --port 8000 --source-group $LB_SG_ID

# Create IAM Role
echo "Creating IAM Role..."
aws iam create-role --role-name treasure-hunt-ec2-role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}'

aws iam attach-role-policy --role-name treasure-hunt-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam attach-role-policy --role-name treasure-hunt-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

INSTANCE_PROFILE_NAME="treasure-hunt-instance-profile"
aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name treasure-hunt-ec2-role

# Create Launch Template
echo "Creating Launch Template..."
LT_ID=$(aws ec2 create-launch-template --launch-template-name treasure-hunt-lt --launch-template-data '{
  "ImageId": "ami-0c55b159cbfafe1f0",
  "InstanceType": "'"$INSTANCE_TYPE"'",
  "KeyName": "'"$KEY_NAME"'",
  "SecurityGroupIds": ["'"$INSTANCE_SG_ID"'"],
  "IamInstanceProfile": {
    "Name": "'"$INSTANCE_PROFILE_NAME"'"
  },
  "UserData": "'$(base64 -w0 <<'EOF'
#!/bin/bash
yum update -y
yum install -y git python3 python3-pip
mkdir -p /home/ec2-user/assignment5
cd /home/ec2-user/assignment5
git clone $GITHUB_REPO .
pip3 install -r requirements.txt
python3 manage.py collectstatic --noinput
nohup python3 manage.py runserver 0.0.0.0:8000 &
EOF
)'"}' --query 'LaunchTemplate.LaunchTemplateId' --output text)

# Create Target Group
echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group --name treasure-hunt-tg --protocol HTTP --port 8000 --vpc-id $VPC_ID --health-check-path=/ --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create Load Balancer
echo "Creating Load Balancer..."
LB_ARN=$(aws elbv2 create-load-balancer --name treasure-hunt-lb --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $LB_SG_ID --query 'LoadBalancers[0].LoadBalancerArn' --output text)
LB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $LB_ARN --query 'LoadBalancers[0].DNSName' --output text)

# Create Listener
echo "Creating Listener..."
aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Create Auto Scaling Group
echo "Creating Auto Scaling Group..."
ASG_NAME="treasure-hunt-asg"
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name $ASG_NAME \
  --launch-template LaunchTemplateId=$LT_ID,Version='$Latest' \
  --min-size $MIN_SIZE \
  --max-size $MAX_SIZE \
  --desired-capacity $DESIRED_CAPACITY \
  --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" \
  --target-group-arns $TG_ARN \
  --health-check-type ELB \
  --health-check-grace-period 300

# Create Scaling Policy
echo "Creating Scaling Policy..."
aws autoscaling put-scaling-policy \
  --policy-name cpu-scaling-policy \
  --auto-scaling-group-name $ASG_NAME \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 10,
    "DisableScaleIn": false
  }'

# Wait for instances to be ready
echo "Waiting for instances to be ready..."
aws autoscaling wait group-in-service --auto-scaling-group-names $ASG_NAME

# Output results
echo "Deployment complete!"
echo "Load Balancer DNS: http://$LB_DNS"
echo "Access your application at: http://$LB_DNS"