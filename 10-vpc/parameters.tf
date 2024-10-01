resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/${var.environment}/vpc_id" # /expense/dev/vpc_id
  type  = "String"
  value = module.vpc.vpc_id
}
resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/public_subnet_ids" # /expense/dev/public_subnet_ids
  type  = "StringList"                                                # becoz we have two public subnet ids 
  value = join(",", module.vpc.public_subnet_ids)
  # joins the two subnet ids eg., ["subnet-1","subnet-2"] --> subnet-1,subnet-2
  # subnet-0e32b43ee2a08c298,subnet-09bcf6611ee998f3f
}
resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/private_subnet_ids" # /expense/dev/private_subnet_ids
  type  = "StringList"                                                 # becoz we have two private subnet ids 
  value = join(",", module.vpc.private_subnet_ids)
  # joins the two subnet ids eg., ["subnet-1","subnet-2"] --> subnet-1,subnet-2
  # subnet-03578840fa631a602,subnet-0875fd277fbdc97b9
}
resource "aws_ssm_parameter" "database_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/database_subnet_ids" # /expense/dev/database_subnet_ids
  type  = "StringList"                                                  # becoz we have two database subnet ids 
  value = join(",", module.vpc.database_subnet_ids)
  # joins the two subnet ids eg., ["subnet-1","subnet-2"] --> subnet-1,subnet-2
  # subnet-0579eb5e4ec20d64e,subnet-0c81c7c70866f34cd
}

resource "aws_ssm_parameter" "database_subnet_group_name" {
  name  = "/${var.project_name}/${var.environment}/database_subnet_group_name"
  type  = "String"
  value = module.vpc.database_subnet_group_name
}