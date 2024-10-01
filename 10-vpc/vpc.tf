module "vpc"{
    # source = "../terraform-aws-vpc"

    # By using this, it pulls the module from git directly no need to be in workspace
    #after completion of module, that we will keep in git and use it
    source = "git::https://github.com/lakshmimungara/terraform-aws-vpc.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    public_subnet_cidrs = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
    database_subnet_cidrs = var.database_subnet_cidrs
    is_peering_required = var.is_peering_required
}