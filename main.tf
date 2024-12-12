module "main_vpc" {
  source = "./modules/vpc"

  deployment_name = var.deployment_name
  vpc_name       = "main"
  vpc_cidr       = var.vpc_cidr

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
  count  = var.enable_quarantine ? 1 : 0

  deployment_name = var.deployment_name
  vpc_name       = "quarantine"
  vpc_cidr       = var.quarantine_vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.quarantine_vpc_cidr, 8, 0)
  public_subnet_1_az    = local.quarantine_public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 1)
  private_subnet_1_az   = local.quarantine_private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 2)
  private_subnet_2_az   = local.quarantine_private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 3)
  private_subnet_3_az   = local.quarantine_private_subnet_3_az
}