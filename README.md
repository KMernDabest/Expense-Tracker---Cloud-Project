# ExpenseTracker-Cloud

A full-stack expense tracking web application deployed on Amazon Web Services (AWS) using Infrastructure as Code (IaC) with Terraform. This project demonstrates cloud best practices including high availability, scalability, security, and observability.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Application Architecture](#application-architecture)
- [Hosting Architecture](#hosting-architecture)
- [AWS Services Used](#aws-services-used)
- [Infrastructure as Code (Terraform)](#infrastructure-as-code-terraform)
- [Networking & Security](#networking--security)
- [Scalability & High Availability](#scalability--high-availability)
- [Observability & Monitoring](#observability--monitoring)
- [Deployment Flow](#deployment-flow)
- [Project Structure](#project-structure)
- [Configuration Variables](#configuration-variables)

---

## Project Overview

ExpenseTracker-Cloud is a personal finance application that allows users to track expenses across custom categories. Users can register, log in, create expense records, view spending summaries, and analyze their spending through dashboard visualizations.

### Key Application Features

- **User Authentication** -- Registration, login, email verification, password reset (JWT-based)
- **Expense Records** -- CRUD operations with title, amount, date, currency (USD/KHR), category, and notes
- **Categories** -- User-defined categories with color coding
- **Dashboard** -- Monthly spending summaries, pie chart breakdowns, top 5 expenses, and currency toggle
- **API Documentation** -- Swagger UI available at `/docs`
- **Auto-Seeding** -- Database is automatically populated with sample data on first launch

---

## Application Architecture

The application follows a **decoupled frontend/backend** architecture:

```
+-------------------+         +-------------------+         +-------------------+
|                   |  HTTP   |                   |  TCP    |                   |
|   React Frontend  +-------->+  Express.js API   +-------->+  PostgreSQL (RDS) |
|   (S3 Static)     |         |  (EC2 Instances)  |         |  (Private Subnet) |
|                   |         |                   |         |                   |
+-------------------+         +--------+----------+         +-------------------+
                                       |
                                       v
                              +-------------------+
                              |   S3 Bucket       |
                              |   (File Storage)  |
                              +-------------------+
```

### Frontend (Client)

| Attribute     | Detail                          |
|---------------|---------------------------------|
| Framework     | React 19 with Vite 7            |
| Styling       | Tailwind CSS 4                  |
| Routing       | React Router DOM 7              |
| HTTP Client   | Axios                           |
| Hosting       | S3 Static Website Hosting       |

**Pages:** Login, Register, Dashboard, Records, Create/Edit Record, Account Management, Email Verification, Forgot/Reset Password

### Backend (Server)

| Attribute     | Detail                          |
|---------------|---------------------------------|
| Runtime       | Node.js 20 LTS                  |
| Framework     | Express.js 5                    |
| ORM           | Sequelize 6 (PostgreSQL)        |
| Auth          | JWT (jsonwebtoken) + bcrypt     |
| Email         | Nodemailer                      |
| Docs          | Swagger (swagger-jsdoc)         |

**API Endpoints:**
- `/api/users` -- Authentication & user management
- `/api/categories` -- Category CRUD
- `/api/records` -- Expense record CRUD
- `/api/summary` -- Spending analytics
- `/health` -- ALB health check endpoint

---

## Hosting Architecture

The entire infrastructure is provisioned in **AWS ap-southeast-1 (Singapore)** using Terraform.

```
                          INTERNET
                             |
                             v
                 +-----------+-----------+
                 |  Application Load     |
                 |  Balancer (ALB)       |
                 |  Port 80 (HTTP)       |
                 +-----+-----+----------+
                       |     |
            +----------+     +----------+
            |                           |
            v                           v
  +---------+---------+      +----------+--------+
  |   EC2 Instance    |      |   EC2 Instance    |
  |   (AZ: 1a)        |      |   (AZ: 1b)        |
  |   t3.micro        |      |   t3.micro        |
  |   Port 3000       |      |   Port 3000       |
  |   Public Subnet   |      |   Public Subnet   |
  +---------+---------+      +----------+--------+
            |                           |
            +----------+     +----------+
                       |     |
                       v     v
              +--------+-----+---------+
              |   RDS PostgreSQL       |
              |   db.t3.micro          |
              |   Private Subnet       |
              |   Port 5432            |
              +-----------+------------+
                          
  +-------------------+     +-------------------+
  | S3: App Files     |     | S3: Frontend      |
  | (Private, SSE)    |     | (Public, Static)  |
  +-------------------+     +-------------------+
```

### Network Layout (VPC: 10.0.0.0/16)

| Subnet Type | CIDR Block   | Availability Zone   | Purpose                      |
|-------------|--------------|---------------------|------------------------------|
| Public      | 10.0.1.0/24  | ap-southeast-1a     | ALB + EC2 instances          |
| Public      | 10.0.2.0/24  | ap-southeast-1b     | ALB + EC2 instances          |
| Private     | 10.0.3.0/24  | ap-southeast-1a     | RDS database                 |
| Private     | 10.0.4.0/24  | ap-southeast-1b     | RDS database                 |

---

## AWS Services Used

### EC2 (Elastic Compute Cloud)

**Purpose:** Hosts the Express.js backend API.

- **Instance Type:** t3.micro (free-tier eligible)
- **AMI:** Amazon Linux (ami-02289b3fe036fe5cd)
- **Configuration:** Instances are provisioned via a Launch Template with user data scripts that automatically clone the application from GitHub, install dependencies, build the frontend, and start the backend as a systemd service.

**Rationale:** EC2 provides full control over the compute environment, allowing custom Node.js runtime configuration and systemd-based process management.

### RDS (Relational Database Service)

**Purpose:** Managed PostgreSQL 15.13 database for storing users, categories, and expense records.

- **Instance Class:** db.t3.micro
- **Storage:** 20 GB gp3 (auto-scales up to 50 GB)
- **Encryption:** Enabled (storage-level encryption at rest)
- **Backups:** 1-day retention period
- **Accessibility:** Private subnets only -- not publicly accessible

**Rationale:** RDS eliminates database administration overhead (patching, backups, failover) while providing a fully managed PostgreSQL engine that Sequelize ORM connects to natively.

### S3 (Simple Storage Service)

Two S3 buckets are provisioned:

1. **Application Files Bucket** (Private)
   - Stores uploaded files and application assets
   - Server-side encryption (AES-256)
   - Versioning enabled
   - All public access blocked

2. **Frontend Bucket** (Public Static Website)
   - Hosts the built React SPA (Vite output)
   - Configured as an S3 static website with `index.html` as both index and error document (SPA routing)
   - Public read access via bucket policy

**Rationale:** S3 provides cost-effective, highly durable (99.999999999%) storage. Hosting the frontend as a static website on S3 decouples it from the backend compute layer, reducing EC2 load and enabling independent scaling.

### IAM (Identity and Access Management)

**Purpose:** Enforces least-privilege access for EC2 instances.

- **EC2 Instance Role** with the following policies:
  - **Custom S3 Policy** -- Allows `PutObject`, `GetObject`, `DeleteObject`, `ListBucket` on both S3 buckets only
  - **CloudWatch Agent Server Policy** -- Enables publishing metrics and logs to CloudWatch
  - **SSM Managed Instance Core** -- Enables AWS Systems Manager for remote management without SSH

**Rationale:** IAM roles attached via instance profiles eliminate the need for hardcoded AWS credentials on EC2 instances, following AWS security best practices.

### VPC (Virtual Private Cloud)

**Purpose:** Network isolation and segmentation.

- **CIDR:** 10.0.0.0/16 (65,536 addresses)
- **Internet Gateway:** Attached for public subnet internet access
- **Route Table:** Public subnets route 0.0.0.0/0 through the Internet Gateway
- **DNS:** Both DNS support and DNS hostnames enabled

**Rationale:** A custom VPC provides network-level isolation. Public subnets host internet-facing resources (ALB, EC2), while private subnets isolate the database from direct internet access.

### ELB (Elastic Load Balancer)

**Purpose:** Distributes incoming HTTP traffic across EC2 instances.

- **Type:** Application Load Balancer (Layer 7)
- **Listener:** Port 80 (HTTP) forwarding to backend target group on port 3000
- **Health Check:** `GET /health` on port 3000 (30-second interval, 3 healthy/unhealthy thresholds)

**Rationale:** The ALB provides a single stable DNS entry point for the application, distributes traffic for high availability, and automatically removes unhealthy instances from rotation.

### ASG (Auto Scaling Group)

**Purpose:** Maintains application resilience and scales based on demand.

- **Desired Capacity:** 2 instances
- **Minimum:** 2 instances (ensures high availability)
- **Maximum:** 4 instances (cost-controlled scaling)
- **Health Check Type:** ELB (instances marked unhealthy if ALB health check fails)
- **Grace Period:** 300 seconds (allows time for application startup)

**Scaling Policies:**
- **Scale Up:** +1 instance when average CPU > 70% for 2 consecutive 2-minute periods
- **Scale Down:** -1 instance when average CPU < 30% for 2 consecutive 2-minute periods
- **Cooldown:** 300 seconds between scaling actions

**Rationale:** ASG ensures the application survives instance failures by automatically replacing unhealthy instances, and handles traffic spikes by scaling horizontally.

### CloudWatch

**Purpose:** Centralized monitoring, logging, and alerting.

**Metrics & Alarms:**

| Alarm                  | Metric                    | Threshold       | Action              |
|------------------------|---------------------------|-----------------|----------------------|
| High CPU (EC2)         | CPUUtilization            | > 70%           | Scale up ASG         |
| Low CPU (EC2)          | CPUUtilization            | < 30%           | Scale down ASG       |
| Unhealthy Hosts (ALB)  | HealthyHostCount          | < 1             | Alert                |
| 5XX Errors (ALB)       | HTTPCode_Target_5XX_Count | > 10 in 5 min   | Alert                |
| High CPU (RDS)         | CPUUtilization            | > 80%           | Alert                |
| Low Storage (RDS)      | FreeStorageSpace          | < 5 GB          | Alert                |

**Dashboard Widgets:**
- EC2 CPU Utilization
- ALB Request Count
- Healthy Host Count
- RDS Metrics (CPU + Storage)
- ALB HTTP Response Codes (2XX vs 5XX)
- ALB Response Time

**Logging:**
- CloudWatch Agent installed on EC2 instances
- Collects application logs (`/var/log/expense-tracker/app.log`) and user data logs (`/var/log/userdata.log`)
- Log group: `/aws/ec2/expense-tracker` (14-day retention)
- Custom metrics: Memory usage and disk usage

**Rationale:** CloudWatch provides a unified view of infrastructure and application health, enables automated scaling responses, and retains logs for debugging production issues.

---

## Infrastructure as Code (Terraform)

All infrastructure is defined in Terraform (>= 1.5.0) using the AWS provider (~> 5.0).

### Terraform Files

| File            | Purpose                                           |
|-----------------|---------------------------------------------------|
| `providers.tf`  | Terraform version constraints and AWS provider     |
| `variables.tf`  | Input variables with defaults and descriptions     |
| `main.tf`       | All resource definitions (VPC, EC2, RDS, S3, etc.) |
| `outputs.tf`    | Output values (ALB DNS, RDS endpoint, URLs, etc.)  |
| `userdata.sh`   | EC2 bootstrap script (template with variables)     |

### Key Outputs After `terraform apply`

| Output                  | Description                                      |
|-------------------------|--------------------------------------------------|
| `alb_dns_name`          | Public URL to access the backend API via ALB     |
| `frontend_url`          | S3 static website URL for the React frontend     |
| `rds_endpoint`          | PostgreSQL connection endpoint                   |
| `s3_bucket_name`        | Application files S3 bucket name                 |
| `cloudwatch_dashboard_url` | Direct link to the CloudWatch dashboard       |
| `asg_name`              | Auto Scaling Group name for monitoring           |

---

## Networking & Security

### Security Group Rules

```
Internet --> [ALB SG: Allow HTTP 80] --> ALB
                                          |
                              [EC2 SG: Allow 3000 from ALB SG]
                                          |
                                        EC2
                                          |
                              [RDS SG: Allow 5432 from EC2 SG]
                                          |
                                        RDS
```

| Security Group | Inbound Rules                                                  | Outbound    |
|----------------|----------------------------------------------------------------|-------------|
| ALB SG         | TCP 80 from 0.0.0.0/0                                         | All traffic |
| EC2 SG         | TCP 3000 from ALB SG, TCP 22 from 0.0.0.0/0, TCP 443 from 0.0.0.0/0 | All traffic |
| RDS SG         | TCP 5432 from EC2 SG only                                     | All traffic |

**Key Security Principles:**
- **Network Isolation:** RDS is only accessible from EC2 instances (private subnets + security group chaining)
- **Least Privilege IAM:** EC2 role only has permissions for specific S3 buckets and CloudWatch
- **No Hardcoded Credentials:** Database password and JWT secret are passed as Terraform sensitive variables
- **Encrypted Storage:** RDS storage encryption enabled, S3 application bucket uses AES-256 SSE

---

## Scalability & High Availability

### Multi-AZ Architecture

- EC2 instances are spread across **2 Availability Zones** (ap-southeast-1a, ap-southeast-1b)
- ALB spans both public subnets, ensuring traffic distribution even if one AZ fails
- RDS subnet group spans both private subnets (ready for Multi-AZ promotion if needed)

### Auto-Recovery Workflow

1. EC2 instance fails or becomes unhealthy
2. ALB health check (`/health`) detects the failure
3. ASG marks the instance as unhealthy
4. ASG terminates the failed instance and launches a replacement
5. New instance runs `userdata.sh` to bootstrap the application
6. ALB registers the new instance once health checks pass

### Scaling Workflow

1. CloudWatch detects CPU > 70% for 4 minutes (2 evaluation periods x 2 minutes)
2. CloudWatch triggers the scale-up alarm
3. ASG launches +1 instance (up to max of 4)
4. 300-second cooldown prevents rapid scaling oscillation
5. When CPU drops below 30%, the reverse process removes instances (down to min of 2)

---

## Deployment Flow

### What Happens on `terraform apply`

1. **VPC & Networking** -- VPC, subnets, internet gateway, and route tables are created
2. **Security Groups** -- ALB, EC2, and RDS security groups are configured
3. **IAM** -- EC2 role, policies, and instance profile are created
4. **S3 Buckets** -- Application files bucket (private) and frontend bucket (public static website)
5. **RDS** -- PostgreSQL instance is provisioned in private subnets
6. **ALB** -- Load balancer, target group, and HTTP listener are created
7. **Launch Template** -- EC2 configuration with `userdata.sh` is prepared
8. **ASG** -- Auto Scaling Group launches desired instances (default: 2)

### What Happens on Each EC2 Instance Boot (userdata.sh)

1. System packages updated (`yum update`)
2. Node.js 20 LTS and Git installed
3. CloudWatch Agent installed and configured (logs + custom metrics)
4. Application code cloned from GitHub
5. Backend `.env` file created with database, JWT, and S3 configuration
6. Backend dependencies installed (`npm install --production`)
7. Frontend built with Vite (`npm run build`) with API URL pointing to ALB
8. Built frontend uploaded to S3 (`aws s3 sync`)
9. Backend registered as a systemd service (`expense-tracker.service`)
10. Service enabled and started on port 3000

---

## Project Structure

```
ExpenseTracker-Cloud/
|-- terraform/                  # Infrastructure as Code
|   |-- providers.tf            # Terraform & AWS provider config
|   |-- variables.tf            # Input variables
|   |-- main.tf                 # All AWS resource definitions
|   |-- outputs.tf              # Output values
|   |-- userdata.sh             # EC2 bootstrap script
|
|-- src/
|   |-- server/                 # Backend API (Express.js)
|   |   |-- app.js              # Express app setup, routes, auto-seeding
|   |   |-- server.js           # Server entry point
|   |   |-- seed.js             # Manual database seeder
|   |   |-- models/             # Sequelize models (User, Record, Category)
|   |   |-- controllers/        # Business logic
|   |   |-- routes/             # API route definitions
|   |   |-- middleware/         # Auth & email verification middleware
|   |   |-- config/             # Swagger configuration
|   |   |-- utils/              # Email service
|   |
|   |-- client/                 # Frontend (React + Vite)
|       |-- src/
|       |   |-- pages/          # Page components (Login, Dashboard, Records, etc.)
|       |   |-- features/       # Feature modules (dashboard, records, categories, account)
|       |   |-- components/     # Shared components (Navbar)
|       |   |-- utils/          # Axios config
|       |   |-- AuthContext.jsx # Authentication context provider
|       |-- vite.config.js
|       |-- vercel.json         # Vercel config (alternative deployment)
|
|-- academic_material/          # Project documentation
```

---

## Configuration Variables

| Variable              | Default               | Description                          | Sensitive |
|-----------------------|-----------------------|--------------------------------------|-----------|
| `aws_region`          | `ap-southeast-1`      | AWS deployment region                | No        |
| `project_name`        | `expense-tracker`     | Prefix for all resource names        | No        |
| `vpc_cidr`            | `10.0.0.0/16`         | VPC CIDR block                       | No        |
| `public_subnet_cidrs` | `10.0.1.0/24, .2.0/24`| Public subnet CIDR blocks           | No        |
| `private_subnet_cidrs`| `10.0.3.0/24, .4.0/24`| Private subnet CIDR blocks          | No        |
| `availability_zones`  | `1a, 1b`              | Deployment availability zones        | No        |
| `ami_id`              | `ami-02289b3fe036fe5cd`| Amazon Linux AMI                    | No        |
| `instance_type`       | `t3.micro`            | EC2 instance type                    | No        |
| `db_name`             | `expensetracker`      | PostgreSQL database name             | No        |
| `db_username`         | `dbadmin`             | Database master username             | Yes       |
| `db_password`         | --                    | Database master password             | Yes       |
| `db_instance_class`   | `db.t3.micro`         | RDS instance type                    | No        |
| `asg_min_size`        | `2`                   | Minimum ASG instances                | No        |
| `asg_max_size`        | `4`                   | Maximum ASG instances                | No        |
| `asg_desired_capacity`| `2`                   | Desired ASG instances                | No        |
| `jwt_secret`          | --                    | JWT signing secret                   | Yes       |
| `github_repo`         | --                    | Repository URL to clone              | No        |
| `email_user`          | `""`                  | Nodemailer email address             | No        |
| `email_pass`          | `""`                  | Nodemailer email password            | Yes       |

---

## Tools & Technologies

| Tool/Service   | Role                                              |
|----------------|----------------------------------------------------|
| Terraform      | Infrastructure as Code -- provisions all AWS resources |
| GitHub         | Version control, collaboration, source for EC2 deployment |
| AWS EC2        | Compute layer for the backend API                  |
| AWS RDS        | Managed PostgreSQL database                        |
| AWS S3         | Static frontend hosting + application file storage |
| AWS ALB        | HTTP load balancing and health checking            |
| AWS ASG        | Auto-scaling and self-healing compute              |
| AWS CloudWatch | Metrics, alarms, logs, and dashboards              |
| AWS IAM        | Role-based access control                          |
| AWS VPC        | Network isolation and segmentation                 |
| Node.js        | Backend runtime                                    |
| Express.js     | Backend web framework                              |
| React          | Frontend UI framework                              |
| Vite           | Frontend build tool                                |
| Sequelize      | ORM for PostgreSQL                                 |
| Tailwind CSS   | Utility-first CSS framework                        |
