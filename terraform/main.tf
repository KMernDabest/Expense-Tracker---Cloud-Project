###############################################################################
# NETWORKING MODULE
###############################################################################

module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

###############################################################################
# SECURITY MODULE
###############################################################################

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

###############################################################################
# STORAGE MODULE
###############################################################################

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
}

###############################################################################
# IAM MODULE
###############################################################################

module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  app_bucket_arn      = module.storage.app_bucket_arn
  frontend_bucket_arn = module.storage.frontend_bucket_arn
}

###############################################################################
# DATABASE MODULE
###############################################################################

module "database" {
  source = "./modules/database"

  project_name      = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id         = module.security.rds_sg_id
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}

###############################################################################
# LOAD BALANCER MODULE
###############################################################################

module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

###############################################################################
# COMPUTE MODULE
###############################################################################

module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  ec2_instance_profile_name = module.iam.ec2_instance_profile_name
  ec2_sg_id                 = module.security.ec2_sg_id
  public_subnet_ids         = module.networking.public_subnet_ids
  target_group_arn          = module.loadbalancer.target_group_arn
  asg_desired_capacity      = var.asg_desired_capacity
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  db_host                   = module.database.db_address
  db_port                   = module.database.db_port
  db_name                   = module.database.db_name
  db_username               = module.database.db_username
  db_password               = module.database.db_password
  jwt_secret                = var.jwt_secret
  s3_bucket                 = module.storage.app_bucket_id
  aws_region                = var.aws_region
  alb_dns                   = module.loadbalancer.alb_dns_name
  email_user                = var.email_user
  email_pass                = var.email_pass
  github_repo               = var.github_repo
  frontend_bucket           = module.storage.frontend_bucket_id
}

###############################################################################
# MONITORING MODULE
###############################################################################

module "monitoring" {
  source = "./modules/monitoring"

  project_name            = var.project_name
  aws_region              = var.aws_region
  asg_name                = module.compute.asg_name
  scale_up_policy_arn     = module.compute.scale_up_policy_arn
  scale_down_policy_arn   = module.compute.scale_down_policy_arn
  alb_arn_suffix          = module.loadbalancer.alb_arn_suffix
  target_group_arn_suffix = module.loadbalancer.target_group_arn_suffix
  db_identifier           = module.database.db_identifier
}
