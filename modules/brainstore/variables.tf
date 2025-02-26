variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore.Must be a Graviton instance type. Preferably with 16GB of memory and a local SSD for cache data. The default value is for tiny deployments. Recommended for production deployments is c7gd.8xlarge."
  default     = "c7gd.xlarge"
}

variable "license_key" {
  type        = string
  description = "The license key for the Brainstore"
}

variable "instance_count" {
  type        = number
  description = "The number of instances to create"
  default     = 1
}

variable "port" {
  type        = number
  description = "The port to use for the Brainstore"
  default     = 4000
}

variable "version_override" {
  type        = string
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  default     = null
}

variable "instance_key_pair_name" {
  type        = string
  description = "Optional. The name of the key pair to use for the Brainstore instances"
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

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting the Brainstore disks and S3 bucket. If not provided, AWS managed keys will be used."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Brainstore resources will be created"
}

variable "security_group_id" {
  type        = string
  description = "The ID of the security group to use for Brainstore resources"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The IDs of the private subnets where Brainstore instances will be launched"
}

# Brainstore depends on the existing Postgres database and Redis instance.
variable "database_secret_arn" {
  type        = string
  description = "The ARN of the secret containing database credentials"
}

variable "database_host" {
  type        = string
  description = "The hostname of the database"
}

variable "database_port" {
  type        = string
  description = "The port of the database"
}

variable "redis_host" {
  type        = string
  description = "The hostname of the Redis instance"
}

variable "redis_port" {
  type        = string
  description = "The port of the Redis instance"
}
