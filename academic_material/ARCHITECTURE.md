# Expense Tracker - AWS Architecture

## Project Overview

The Expense Tracker is a full-stack web application deployed on AWS using Terraform as Infrastructure as Code (IaC). The application consists of a **Node.js/Express** backend API with a **React** frontend, backed by a **PostgreSQL** database on **Amazon RDS**. The infrastructure is designed for **high availability**, **scalability**, **security**, and **observability**.

---

## Architecture Diagram

```
                          ┌─────────────────────────────────────────────────────────┐
                          │                        INTERNET                         │
                          └────────────────────────────┬────────────────────────────┘
                                                       │
                                                       ▼
                          ┌─────────────────────────────────────────────────────────┐
                          │              Application Load Balancer (ALB)            │
                          │                    (Public - Port 80)                   │
                          │                   expense-tracker-alb                   │
                          └────────────┬───────────────────────────────┬────────────┘
                                       │                               │
                    ┌──────────────────────────────┐  ┌──────────────────────────────┐
                    │    PUBLIC SUBNET 1            │  │    PUBLIC SUBNET 2            │
                    │    10.0.1.0/24                │  │    10.0.2.0/24                │
                    │    ap-southeast-1a            │  │    ap-southeast-1b            │
                    │                              │  │                              │
                    │  ┌────────────────────────┐  │  │  ┌────────────────────────┐  │
                    │  │    EC2 (t3.micro)       │  │  │  │    EC2 (t3.micro)       │  │
                    │  │    Amazon Linux          │  │  │  │    Amazon Linux          │  │
                    │  │    Node.js Backend       │  │  │  │    Node.js Backend       │  │
                    │  │    Port 3000             │  │  │  │    Port 3000             │  │
                    │  └────────────┬─────────────┘  │  │  └────────────┬─────────────┘  │
                    └───────────────┼────────────────┘  └───────────────┼────────────────┘
                                    │                                   │
                    ┌───────────────┼───────────────────────────────────┼────────────────┐
                    │               │      Auto Scaling Group (ASG)     │                │
                    │               │      Min: 2 | Desired: 2 | Max: 4│                │
                    └───────────────┼───────────────────────────────────┼────────────────┘
                                    │                                   │
                                    ▼                                   ▼
                    ┌──────────────────────────────┐  ┌──────────────────────────────┐
                    │    PRIVATE SUBNET 1           │  │    PRIVATE SUBNET 2           │
                    │    10.0.3.0/24                │  │    10.0.4.0/24                │
                    │    ap-southeast-1a            │  │    ap-southeast-1b            │
                    │                              │  │                              │
                    │  ┌────────────────────────┐  │  │                              │
                    │  │    RDS PostgreSQL       │  │  │     (Standby for             │
                    │  │    db.t3.micro          │  │  │      DB Subnet Group)        │
                    │  │    Port 5432            │  │  │                              │
                    │  └────────────────────────┘  │  │                              │
                    └──────────────────────────────┘  └──────────────────────────────┘

                    ┌──────────────────────────────────────────────────────────────────┐
                    │                        SUPPORTING SERVICES                       │
                    │                                                                  │
                    │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐  │
                    │  │     S3       │  │  CloudWatch   │  │         IAM            │  │
                    │  │  File Store  │  │  Logs/Alarms  │  │  EC2 Role + Policies   │  │
                    │  │  (Encrypted) │  │  Dashboard    │  │  (Least Privilege)     │  │
                    │  └──────────────┘  └──────────────┘  └────────────────────────┘  │
                    └──────────────────────────────────────────────────────────────────┘

                    VPC: 10.0.0.0/16  |  Region: ap-southeast-1 (Singapore)
```

---

## AWS Services Used & Rationale

### Compute

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **EC2 (t3.micro)** | Hosts the Node.js/Express backend API | Cost-effective general-purpose instance suitable for lightweight API workloads. Runs in `ap-southeast-1` using Amazon Linux AMI `ami-02289b3fe036fe5cd`. |
| **Auto Scaling Group** | Manages EC2 fleet (min: 2, max: 4) | Ensures high availability with instances across 2 AZs. Automatically replaces unhealthy instances and scales based on CPU utilization. |
| **Launch Template** | Defines EC2 instance configuration | Standardizes instance provisioning with user data script, IAM profile, and security group attachments. |

### Networking

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **VPC (10.0.0.0/16)** | Isolated virtual network | Provides network isolation for all resources. Custom CIDR gives full control over IP addressing. |
| **Public Subnets (x2)** | Hosts ALB and EC2 instances | Spread across 2 AZs (`ap-southeast-1a`, `ap-southeast-1b`) for fault tolerance. Instances need internet access to install dependencies. |
| **Private Subnets (x2)** | Hosts RDS database | Database is not publicly accessible - only reachable from EC2 instances within the VPC. |
| **Internet Gateway** | Enables internet connectivity | Required for public subnets to communicate with the internet. |
| **Application Load Balancer** | Distributes traffic across EC2 instances | Layer 7 load balancer that routes HTTP traffic on port 80 to backend instances on port 3000. Performs health checks to route only to healthy targets. |

### Database

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **RDS PostgreSQL 15** | Relational database for application data | Managed PostgreSQL service matching the application's Sequelize ORM dialect. Deployed in private subnets with encryption at rest, automated backups (7-day retention), and auto-scaling storage (20-50 GB). |

### Storage

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **S3 Bucket** | File/image storage for the application | Serverless object storage with versioning enabled, AES-256 encryption, and all public access blocked. Cost-effective for storing user-uploaded files. |

### Security

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **IAM Role + Instance Profile** | EC2 permissions | Follows least-privilege principle - EC2 instances can only access the specific S3 bucket and CloudWatch. No hardcoded credentials. |
| **Security Groups** | Network-level access control | Three-tier security: ALB SG (internet -> port 80), EC2 SG (ALB -> port 3000), RDS SG (EC2 -> port 5432). Each layer only accepts traffic from the layer above. |
| **S3 Public Access Block** | Prevents accidental data exposure | All four public access block settings enabled to ensure bucket contents remain private. |
| **RDS Encryption** | Data-at-rest encryption | Storage encryption enabled using AWS-managed keys for compliance and data protection. |

### Observability

| Service | Purpose | Rationale |
|---------|---------|-----------|
| **CloudWatch Alarms** | Automated alerting | 6 alarms configured: EC2 high/low CPU (triggers ASG scaling), unhealthy host count, ALB 5XX errors, RDS CPU, and RDS storage. |
| **CloudWatch Logs** | Centralized logging | Application logs and user data script logs streamed to CloudWatch via the CloudWatch Agent. 14-day retention. |
| **CloudWatch Dashboard** | Visual monitoring | Pre-built dashboard showing EC2 CPU, ALB request count, healthy hosts, RDS metrics, HTTP response codes, and response times. |
| **CloudWatch Agent** | System-level metrics | Collects custom metrics (memory usage, disk usage) not available through standard EC2 monitoring. |

---

## Security Architecture

The infrastructure implements defense-in-depth with multiple security layers:

1. **Network Isolation**: VPC with public/private subnet separation. RDS is in private subnets with no internet access.
2. **Security Group Chaining**: Traffic flows through ALB SG -> EC2 SG -> RDS SG. Each group only allows traffic from the preceding layer.
3. **IAM Least Privilege**: EC2 role has only S3 bucket-specific permissions and CloudWatch agent access. No wildcard policies.
4. **Encryption**: S3 uses AES-256 server-side encryption. RDS uses AWS-managed encryption at rest.
5. **No Public Database**: RDS `publicly_accessible = false` ensures the database is only reachable from within the VPC.
6. **Sensitive Variables**: Database passwords and JWT secrets are marked as `sensitive` in Terraform to prevent exposure in logs.

---

## High Availability & Scaling

### High Availability
- **Multi-AZ EC2 deployment**: ASG spans `ap-southeast-1a` and `ap-southeast-1b` with a minimum of 2 instances.
- **ELB health checks**: ALB continuously monitors instance health on port 3000. Unhealthy instances are automatically deregistered and replaced by the ASG.
- **Auto-recovery**: If an EC2 instance fails or is terminated, the ASG automatically launches a replacement to maintain desired capacity.

### Auto Scaling Policies
- **Scale Up**: When average CPU > 70% for 4 minutes (2 evaluation periods x 120s), add 1 instance (up to max 4).
- **Scale Down**: When average CPU < 30% for 4 minutes, remove 1 instance (down to min 2).
- **Cooldown**: 5-minute cooldown between scaling actions to prevent oscillation.

### Simulating Failure & Recovery
To demonstrate ASG auto-recovery:
```bash
# 1. List current instances
aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`expense-tracker-asg`].InstanceId'

# 2. Terminate an instance to simulate failure
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# 3. Watch ASG launch a replacement
aws autoscaling describe-auto-scaling-group \
  --auto-scaling-group-names expense-tracker-asg \
  --query 'AutoScalingGroups[0].Instances'
```

---

## Cost Estimation

| Service | Configuration | Estimated Monthly Cost (USD) |
|---------|--------------|------------------------------|
| EC2 (t3.micro x2) | 2 instances, on-demand | ~$15.04 |
| RDS (db.t3.micro) | Single-AZ, 20GB gp3 | ~$14.98 |
| ALB | 1 ALB + LCUs | ~$18.40 |
| S3 | < 1 GB storage | ~$0.03 |
| CloudWatch | Logs, alarms, dashboard | ~$3.00 |
| Data Transfer | Minimal | ~$1.00 |
| **Total** | | **~$52.45/month** |

*Estimates based on ap-southeast-1 pricing. Actual costs may vary based on usage.*

---

## Terraform File Structure

```
terraform/
├── providers.tf              # AWS provider and Terraform version constraints
├── variables.tf              # All input variables with descriptions and defaults
├── main.tf                   # Core infrastructure resources:
│                             #   - VPC, Subnets, Internet Gateway, Route Tables
│                             #   - Security Groups (ALB, EC2, RDS)
│                             #   - IAM Role, Policies, Instance Profile
│                             #   - S3 Bucket (versioned, encrypted, private)
│                             #   - RDS PostgreSQL instance
│                             #   - Application Load Balancer + Target Group
│                             #   - Launch Template + Auto Scaling Group
│                             #   - CloudWatch Alarms, Logs, and Dashboard
├── outputs.tf                # Output values (ALB DNS, RDS endpoint, etc.)
├── userdata.sh               # EC2 bootstrap script (Node.js, app setup, CloudWatch Agent)
└── terraform.tfvars.example  # Example variable values (copy to terraform.tfvars)
```

---

## Deployment Instructions

```bash
# 1. Navigate to terraform directory
cd terraform/

# 2. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your db_password and jwt_secret

# 3. Initialize Terraform
terraform init

# 4. Preview the infrastructure changes
terraform plan

# 5. Deploy the infrastructure
terraform apply

# 6. Access the application
# The ALB DNS name will be printed as an output
# Visit: http://<alb_dns_name>
```

---

## Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| Database accessibility from EC2 only | Placed RDS in private subnets with security group allowing only EC2 SG ingress on port 5432 |
| Application code deployment to EC2 | User data script bootstraps Node.js environment and configures systemd service. Source code should be pulled from S3 or GitHub during deployment. |
| Scaling without downtime | ALB + ASG with rolling updates ensure zero-downtime scaling. Health check grace period (300s) prevents premature termination of booting instances. |
| Centralized logging | CloudWatch Agent installed via user data, streaming application and system logs to CloudWatch Log Groups with 14-day retention. |
| Credential management | Terraform `sensitive` flag on passwords/secrets. Environment variables injected via user data script - not hardcoded in application code. |
