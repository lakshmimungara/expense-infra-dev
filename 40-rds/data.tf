data "aws_ssm_parameter" "mysql_sg_id"{
    name = "/${var.project_name}/${var.environment}/mysql_sg_id"  # /expense/dev/bastion_sg_id

}

data "aws_ssm_parameter" "database_subnet_group_name"{
    name = "/${var.project_name}/${var.environment}/database_subnet_group_name"  # /expense/dev/bastion_sg_id

}

# data "aws_ssm_parameter" "public_subnet_ids"{
#     # we will get stringList by using this 
#     # we cannot perform operations on string list 
#     # So, we convert stringList to List and perform reverse operations
#     # And then we have to select one subnet 
#     name = "/${var.project_name}/${var.environment}/public_subnet_ids"  # /expense/dev/public_subnet_ids

# }

