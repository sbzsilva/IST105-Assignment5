# IST105 - Assignment 5: Interactive Treasure Hunt

This is a Django-based interactive web application for a treasure hunt puzzle.

## Features
- Number Puzzle: Determines if a number is even or odd, then calculates square root (if even) or cube (if odd)
- Text Puzzle: Converts text to binary and counts vowels
- Treasure Hunt: Simulates guessing a random number (1-100) in 5 tries or less

## Deployment
The application is deployed on AWS using Auto Scaling Groups and a Load Balancer.

## Repository Structure
- `assignment5/`: Django project directory
- `puzzle/`: Django app directory containing the treasure hunt logic
- `manage.py`: Django's command-line utility
- `requirements.txt`: Python dependencies
- `README.md`: This file

## Branches
- `main`: Final version
- `development`: Integration testing
- `feature1`: Initial development

## Running Locally
1. Create a virtual environment and activate it
2. Install dependencies: `pip install -r requirements.txt`
3. Run migrations: `python manage.py migrate`
4. Start the server: `python manage.py runserver`
5. Access at http://127.0.0.1:8000/

## Deployment on AWS
The deployment is automated using AWS CLI and a shell script. The script creates:
- VPC, Subnets, Internet Gateway, Route Table
- Security Groups for Load Balancer and EC2 instances
- IAM Role and Instance Profile
- Launch Template
- Target Group
- Load Balancer
- Auto Scaling Group with scaling policy

After deployment, the application can be accessed via the Load Balancer DNS.