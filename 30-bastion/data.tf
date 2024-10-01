data "aws_ssm_parameter" "bastion_sg_id"{
    name = "/${var.project_name}/${var.environment}/bastion_sg_id"  # /expense/dev/bastion_sg_id

}

data "aws_ssm_parameter" "public_subnet_ids"{
    # we will get stringList by using this 
    # we cannot perform operations on string list 
    # So, we convert stringList to List and perform reverse operations
    # And then we have to select one subnet 
    name = "/${var.project_name}/${var.environment}/public_subnet_ids"  # /expense/dev/public_subnet_ids

}

data "aws_ami" "joindevops" {
	
    most_recent  = true 
	owners = ["973714476881"]   # unique   -> till this line we will get the All recent AMI from joindevops
	
	filter {
		name = "name"
		values = ["RHEL-9-DevOps-Practice"]
	}
	
	filter {
		name = "root-device-type"
		values = ["ebs"]
	}
	
	filter {
		name = "virtualization-type"
		values = ["hvm"]
	}
}