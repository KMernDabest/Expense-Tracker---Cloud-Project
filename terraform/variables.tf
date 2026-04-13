variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "expense-tracker"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (for RDS)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for high availability"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux)"
  type        = string
  default     = "ami-02289b3fe036fe5cd"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "expensetracker"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "jwt_secret" {
  description = "JWT secret for the application"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository URL to clone the application code"
  type        = string
}

variable "email_user" {
  description = "Email address for nodemailer"
  type        = string
  default     = ""
}

variable "email_pass" {
  description = "Email password for nodemailer"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}
