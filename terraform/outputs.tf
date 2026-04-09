output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (access the app here)"
  value       = module.loadbalancer.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.db_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket name for application files"
  value       = module.storage.app_bucket_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-dashboard"
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = module.monitoring.log_group_name
}

output "frontend_url" {
  description = "Frontend S3 website URL"
  value       = module.storage.frontend_website_endpoint
}

output "frontend_bucket_name" {
  description = "Frontend S3 bucket name"
  value       = module.storage.frontend_bucket_id
}
