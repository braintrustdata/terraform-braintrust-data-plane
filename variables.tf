locals {
  # Lookup and choose an AZ if not provided
  private_subnet_1_az = var.private_subnet_1_az != null ? var.private_subnet_1_az : data.aws_availability_zones.available.names[0]
  private_subnet_2_az = var.private_subnet_2_az != null ? var.private_subnet_2_az : data.aws_availability_zones.available.names[1]
  private_subnet_3_az = var.private_subnet_3_az != null ? var.private_subnet_3_az : data.aws_availability_zones.available.names[2]
  public_subnet_1_az  = var.public_subnet_1_az != null ? var.public_subnet_1_az : data.aws_availability_zones.available.names[0]

  # Lookup and choose an AZ if not provided for Quarantine VPC
  quarantine_private_subnet_1_az = var.quarantine_private_subnet_1_az != null ? var.quarantine_private_subnet_1_az : data.aws_availability_zones.available.names[0]
  quarantine_private_subnet_2_az = var.quarantine_private_subnet_2_az != null ? var.quarantine_private_subnet_2_az : data.aws_availability_zones.available.names[1]
  quarantine_private_subnet_3_az = var.quarantine_private_subnet_3_az != null ? var.quarantine_private_subnet_3_az : data.aws_availability_zones.available.names[2]
  quarantine_public_subnet_1_az  = var.quarantine_public_subnet_1_az != null ? var.quarantine_public_subnet_1_az : data.aws_availability_zones.available.names[0]
}

variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names. Lowercase letter, numbers, and hyphens only. If you want multiple deployments in your same AWS account, use a unique name for each deployment."
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.deployment_name))
    error_message = "The deployment_name must contain only lowercase letters, numbers and hyphens in order to be compatible with AWS resource naming restrictions."
  }
  validation {
    condition     = length(var.deployment_name) <= 18
    error_message = "The deployment_name must be 18 characters or less."
  }
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN to use for encrypting resources. If not provided, a new key will be created. DO NOT change this after deployment. If you do, it will attempt to destroy your DB and prior S3 objects will no longer be readable."
  type        = string
  default     = null
}

variable "additional_kms_key_policies" {
  description = "Additional IAM policy statements to append to the generated KMS key."
  type        = list(any)
  default     = []
  validation {
    condition     = length(var.additional_kms_key_policies) == 0 || var.kms_key_arn == null
    error_message = "additional_kms_key_policies can only be used if kms_key_arn is not provided."
  }
}

## NETWORKING
variable "vpc_cidr" {
  type        = string
  default     = "10.175.0.0/16"
  description = "CIDR block for the VPC"
}

variable "private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}

variable "enable_quarantine_vpc" {
  type        = bool
  description = "Enable the Quarantine VPC to run user defined functions in an isolated environment. If disabled, user defined functions will not be available."
  default     = true
}

variable "quarantine_vpc_cidr" {
  type        = string
  default     = "10.176.0.0/16"
  description = "CIDR block for the Quarantined VPC"
}

variable "quarantine_private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "quarantine_private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "quarantine_private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "quarantine_public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}


## Database
variable "postgres_instance_type" {
  description = "Instance type for the RDS instance."
  type        = string
  default     = "db.t4g.xlarge"
}

variable "postgres_storage_size" {
  description = "Storage size (in GB) for the RDS instance."
  type        = number
  default     = 100
}

variable "postgres_storage_type" {
  description = "Storage type for the RDS instance."
  type        = string
  default     = "gp3"
}

variable "postgres_storage_iops" {
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3."
  type        = number
  default     = null
}

variable "postgres_storage_throughput" {
  description = "Throughput for the RDS instance. Only applicable if storage_type is gp3."
  type        = number
  default     = null
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15.7"
}

## Redis
variable "redis_instance_type" {
  description = "Instance type for the Redis cluster"
  type        = string
  default     = "cache.t4g.small"
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

## Services

variable "api_handler_provisioned_concurrency" {
  description = "The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost."
  type        = number
  default     = 0
}

variable "whitelisted_origins" {
  description = "List of origins to whitelist for CORS"
  type        = list(string)
  default     = []
}

variable "outbound_rate_limit_max_requests" {
  description = "The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits"
  type        = number
  default     = 0
}

variable "outbound_rate_limit_window_minutes" {
  description = "The time frame in minutes over which rate per-user rate limits are accumulated"
  type        = number
  default     = 1
}

variable "custom_domain" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
  default     = null
}

variable "custom_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = null
}

## Clickhouse
variable "enable_clickhouse" {
  type        = bool
  description = "Enable Clickhouse for faster analytics"
  default     = false
}

variable "use_external_clickhouse_address" {
  type        = string
  description = "Do not change this unless instructed by Braintrust. If set, the domain name or IP of the external Clickhouse instance will be used and no internal instance will be created."
  default     = null
}

variable "clickhouse_metadata_storage_size" {
  type        = number
  description = "The size of the EBS volume to use for Clickhouse metadata"
  default     = 100
}

variable "clickhouse_instance_type" {
  type        = string
  description = "The instance type to use for the Clickhouse instance"
  default     = "c5.2xlarge"
}

## Brainstore
variable "enable_brainstore" {
  type        = bool
  description = "Enable Brainstore for faster analytics"
  default     = false
}

variable "brainstore_instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore.Must be a Graviton instance type. Preferably with 16GB of memory and a local SSD for cache data. The default value is for tiny deployments. Recommended for production deployments is c7gd.8xlarge."
  default     = "c5.xlarge"
}

variable "brainstore_instance_count" {
  type        = number
  description = "The number of Brainstore instances to provision"
  default     = 1
}

variable "brainstore_instance_key_pair_name" {
  type        = string
  description = "The name of the key pair to use for the Brainstore instance"
  default     = null
}

variable "brainstore_port" {
  type        = number
  description = "The port to use for the Brainstore instance"
  default     = 4000
}

variable "brainstore_license_key" {
  type        = string
  description = "The license key for the Brainstore instance"
  default     = null
}

variable "brainstore_version_override" {
  type        = string
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  default     = null
}

variable "brainstore_backfill_all_objects" {
  type        = bool
  description = "Run a full historical backfill of all objects."
  default     = false
}

variable "brainstore_backfill_only_realtime" {
  type        = bool
  description = "Only backfill to keep realtime objects up-to-date. (This is an advanced setting you should only use to debug with the Braintrust team)."
  default     = false
}

variable "brainstore_backfill_only_historical" {
  type        = bool
  description = "Only backfill to keep historical objects up-to-date. (This is an advanced setting you should only use to debug with the Braintrust team)."
  default     = false
}



