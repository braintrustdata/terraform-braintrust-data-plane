module "kms" {
  source = "./modules/kms"
  count  = var.kms_key_arn == null ? 1 : 0

  deployment_name         = var.deployment_name
  additional_key_policies = var.additional_kms_key_policies
}

locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : module.kms[0].key_arn
  clickhouse_address = var.use_external_clickhouse_address != null ? var.use_external_clickhouse_address : (
    var.enable_clickhouse ? module.clickhouse[0].clickhouse_instance_private_ip : null
  )
}

module "main_vpc" {
  source = "./modules/vpc"

  deployment_name = var.deployment_name
  vpc_name        = "main"
  vpc_cidr        = var.vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.vpc_cidr, 8, 0)
  public_subnet_1_az    = local.public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.vpc_cidr, 8, 1)
  private_subnet_1_az   = local.private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.vpc_cidr, 8, 2)
  private_subnet_2_az   = local.private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.vpc_cidr, 8, 3)
  private_subnet_3_az   = local.private_subnet_3_az
}

module "quarantine_vpc" {
  source = "./modules/vpc"
  count  = var.enable_quarantine_vpc ? 1 : 0

  deployment_name = var.deployment_name
  vpc_name        = "quarantine"
  vpc_cidr        = var.quarantine_vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.quarantine_vpc_cidr, 8, 0)
  public_subnet_1_az    = local.quarantine_public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 1)
  private_subnet_1_az   = local.quarantine_private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 2)
  private_subnet_2_az   = local.quarantine_private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 3)
  private_subnet_3_az   = local.quarantine_private_subnet_3_az
}

module "database" {
  source                 = "./modules/database"
  deployment_name        = var.deployment_name
  postgres_instance_type = var.postgres_instance_type
  postgres_storage_size  = var.postgres_storage_size
  postgres_storage_type  = var.postgres_storage_type
  postgres_version       = var.postgres_version
  database_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  database_security_group_ids = [module.main_vpc.default_security_group_id]

  postgres_storage_iops       = var.postgres_storage_iops
  postgres_storage_throughput = var.postgres_storage_throughput

  kms_key_arn = local.kms_key_arn
}

module "redis" {
  source = "./modules/elasticache"

  deployment_name = var.deployment_name
  subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  security_group_ids  = [module.main_vpc.default_security_group_id]
  redis_instance_type = var.redis_instance_type
  redis_version       = var.redis_version
}

module "services" {
  source = "./modules/services"

  deployment_name = var.deployment_name

  # Data stores
  postgres_username = module.database.postgres_database_username
  postgres_password = module.database.postgres_database_password
  postgres_host     = module.database.postgres_database_address
  postgres_port     = module.database.postgres_database_port
  redis_host        = module.redis.redis_endpoint
  redis_port        = module.redis.redis_port

  clickhouse_host      = local.clickhouse_address
  clickhouse_secret_id = var.enable_clickhouse ? module.clickhouse[0].clickhouse_secret_id : null

  # Service configuration
  braintrust_org_name                 = var.braintrust_org_name
  api_handler_provisioned_concurrency = var.api_handler_provisioned_concurrency
  whitelisted_origins                 = var.whitelisted_origins
  outbound_rate_limit_window_minutes  = var.outbound_rate_limit_window_minutes
  outbound_rate_limit_max_requests    = var.outbound_rate_limit_max_requests
  custom_domain                       = var.custom_domain
  custom_certificate_arn              = var.custom_certificate_arn

  # Networking
  service_security_group_ids = [module.main_vpc.default_security_group_id]
  service_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]

  # Quarantine VPC
  use_quarantine_vpc                       = var.enable_quarantine_vpc
  quarantine_vpc_id                        = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  quarantine_vpc_default_security_group_id = var.enable_quarantine_vpc ? module.quarantine_vpc[0].default_security_group_id : null
  quarantine_vpc_private_subnets = var.enable_quarantine_vpc ? [
    module.quarantine_vpc[0].private_subnet_1_id,
    module.quarantine_vpc[0].private_subnet_2_id,
    module.quarantine_vpc[0].private_subnet_3_id
  ] : []

  kms_key_arn = local.kms_key_arn
}

module "clickhouse" {
  source = "./modules/clickhouse"
  count  = var.enable_clickhouse ? 1 : 0

  deployment_name                  = var.deployment_name
  clickhouse_instance_count        = var.use_external_clickhouse_address != null ? 0 : 1
  clickhouse_instance_type         = var.clickhouse_instance_type
  clickhouse_metadata_storage_size = var.clickhouse_metadata_storage_size
  clickhouse_subnet_id             = module.main_vpc.private_subnet_1_id
  clickhouse_security_group_ids    = [module.main_vpc.default_security_group_id]

  kms_key_arn = local.kms_key_arn
}

module "brainstore" {
  source = "./modules/brainstore"
  count  = var.enable_brainstore ? 1 : 0

  deployment_name        = var.deployment_name
  instance_count         = var.brainstore_instance_count
  instance_type          = var.brainstore_instance_type
  instance_key_pair_name = var.brainstore_instance_key_pair_name
  port                   = var.brainstore_port
  license_key            = var.brainstore_license_key
  version_override       = var.brainstore_version_override

  database_host       = module.database.postgres_database_address
  database_port       = module.database.postgres_database_port
  database_secret_arn = module.database.postgres_database_secret_arn
  redis_host          = module.redis.redis_endpoint
  redis_port          = module.redis.redis_port

  vpc_id            = module.main_vpc.vpc_id
  security_group_id = module.main_vpc.default_security_group_id
  private_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]

  kms_key_arn = local.kms_key_arn
}
