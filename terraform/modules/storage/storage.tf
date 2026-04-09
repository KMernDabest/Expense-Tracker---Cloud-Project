###############################################################################
# VARIABLES
###############################################################################

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

###############################################################################
# S3 BUCKET (APPLICATION FILES)
###############################################################################

resource "aws_s3_bucket" "app_bucket" {
  bucket_prefix = "${var.project_name}-files-"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-files"
  }
}

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_sse" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket_pab" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# S3 BUCKET (FRONTEND STATIC WEBSITE)
###############################################################################

resource "aws_s3_bucket" "frontend_bucket" {
  bucket_prefix = "${var.project_name}-frontend-"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_pab" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket     = aws_s3_bucket.frontend_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.frontend_pab]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

###############################################################################
# OUTPUTS
###############################################################################

output "app_bucket_id" {
  description = "Application S3 bucket ID"
  value       = aws_s3_bucket.app_bucket.id
}

output "app_bucket_arn" {
  description = "Application S3 bucket ARN"
  value       = aws_s3_bucket.app_bucket.arn
}

output "frontend_bucket_id" {
  description = "Frontend S3 bucket ID"
  value       = aws_s3_bucket.frontend_bucket.id
}

output "frontend_bucket_arn" {
  description = "Frontend S3 bucket ARN"
  value       = aws_s3_bucket.frontend_bucket.arn
}

output "frontend_website_endpoint" {
  description = "Frontend S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}