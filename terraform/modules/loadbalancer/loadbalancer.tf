###############################################################################
# VARIABLES
###############################################################################

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB security group ID"
  type        = string
}

###############################################################################
# RESOURCES
###############################################################################

resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for backend API (port 3000)
resource "aws_lb_target_group" "backend_tg" {
  name     = "${var.project_name}-backend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "3000"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}

# ALB Listener - forward HTTP to backend
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

###############################################################################
# OUTPUTS
###############################################################################

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app_alb.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch"
  value       = aws_lb.app_alb.arn_suffix
}

output "target_group_arn" {
  description = "Backend target group ARN"
  value       = aws_lb_target_group.backend_tg.arn
}

output "target_group_arn_suffix" {
  description = "Backend target group ARN suffix for CloudWatch"
  value       = aws_lb_target_group.backend_tg.arn_suffix
}
