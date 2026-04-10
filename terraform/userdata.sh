#!/bin/bash
set -e

# Log all output for debugging
exec > /var/log/userdata.log 2>&1
echo "=== User Data Script Started at $(date) ==="

# Update system packages
yum update -y

# Install Node.js 20 LTS
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs git

# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/expense-tracker/app.log",
            "log_group_name": "/aws/ec2/expense-tracker",
            "log_stream_name": "{instance_id}/app",
            "retention_in_days": 14
          },
          {
            "file_path": "/var/log/userdata.log",
            "log_group_name": "/aws/ec2/expense-tracker",
            "log_stream_name": "{instance_id}/userdata",
            "retention_in_days": 14
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "ExpenseTracker",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Create directories
mkdir -p /home/ec2-user/app
mkdir -p /var/log/expense-tracker

# Clone application code from GitHub
echo "=== Cloning application from GitHub ==="
cd /home/ec2-user
git clone ${github_repo} repo
cp -r repo/src/server/* /home/ec2-user/app/
cp -r repo/src/client /home/ec2-user/client

# Create environment file for the backend
cat > /home/ec2-user/app/.env <<ENVFILE
PORT=3000
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_DIALECT=postgres
JWT_SECRET=${jwt_secret}
FRONTEND_URL=http://${frontend_bucket}.s3-website-ap-southeast-1.amazonaws.com
BACKEND_URL=http://${alb_dns}
S3_BUCKET=${s3_bucket}
AWS_REGION=${aws_region}
EMAIL_USERNAME=${email_user}
EMAIL_PASSWORD=${email_pass}
ENVFILE

# Install backend dependencies
echo "=== Installing backend dependencies ==="
cd /home/ec2-user/app
npm install --production 2>&1 | tee /var/log/expense-tracker/npm-install.log

# Build the React frontend and upload to S3
echo "=== Building frontend ==="
cd /home/ec2-user/client
cat > .env <<FRONTENV
VITE_API_BASE_URL=http://${alb_dns}/api
FRONTENV
npm install 2>&1 | tee /var/log/expense-tracker/npm-install-client.log
npm run build 2>&1 | tee /var/log/expense-tracker/vite-build.log

# Upload built frontend to S3
echo "=== Uploading frontend to S3 ==="
aws s3 sync /home/ec2-user/client/dist s3://${frontend_bucket}/ --delete 2>&1 | tee /var/log/expense-tracker/s3-upload.log

# Set ownership
chown -R ec2-user:ec2-user /home/ec2-user/app
chown -R ec2-user:ec2-user /home/ec2-user/client
chown -R ec2-user:ec2-user /var/log/expense-tracker

# Create systemd service for the backend
cat > /etc/systemd/system/expense-tracker.service <<'SERVICE'
[Unit]
Description=Expense Tracker Backend API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/expense-tracker/app.log
StandardError=append:/var/log/expense-tracker/app.log
EnvironmentFile=/home/ec2-user/app/.env

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
systemctl daemon-reload
systemctl enable expense-tracker
systemctl start expense-tracker

echo "=== User Data Script Completed at $(date) ==="