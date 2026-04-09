###############################################################################
# VARIABLES
###############################################################################

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "EC2 IAM instance profile name"
  type        = string
}

variable "ec2_sg_id" {
  description = "EC2 security group ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ASG"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "asg_desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "asg_min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "db_host" {
  description = "Database host address"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret"
  type        = string
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket name for app files"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alb_dns" {
  description = "ALB DNS name"
  type        = string
}

variable "email_user" {
  description = "Email user for nodemailer"
  type        = string
}

variable "email_pass" {
  description = "Email password for nodemailer"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
}

variable "frontend_bucket" {
  description = "Frontend S3 bucket name"
  type        = string
}

###############################################################################
# RESOURCES
###############################################################################

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  vpc_security_group_ids = [var.ec2_sg_id]

  user_data = base64encode(templatefile("${path.module}/../../userdata.sh", {
    db_host         = var.db_host
    db_port         = var.db_port
    db_name         = var.db_name
    db_user         = var.db_username
    db_password     = var.db_password
    jwt_secret      = var.jwt_secret
    s3_bucket       = var.s3_bucket
    aws_region      = var.aws_region
    alb_dns         = var.alb_dns
    email_user      = var.email_user
    email_pass      = var.email_pass
    github_repo     = var.github_repo
    frontend_bucket = var.frontend_bucket
  }))

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.project_name}-asg"
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.public_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"

  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

# Scale Up Policy - when CPU > 70%
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# Scale Down Policy - when CPU < 30%
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

###############################################################################
# OUTPUTS
###############################################################################

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app_asg.name
}

output "scale_up_policy_arn" {
  description = "Scale up policy ARN"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "Scale down policy ARN"
  value       = aws_autoscaling_policy.scale_down.arn
}
