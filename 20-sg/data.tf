# we use data source for quering the existing information 
data "aws_ssm_parameter" "vpc_id"{
    name = "/${var.project_name}/${var.environment}/vpc_id"
}