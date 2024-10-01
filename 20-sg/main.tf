# SG for mysql 
module "mysql_sg" {
    source = "git::https://github.com/lakshmimungara/terraform-aws-security-group.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    sg_name = "mysql"
    vpc_id = local.vpc_id 
    common_tags = var.common_tags
    sg_tags = var.mysql_sg_tags
}

# Sg for backend
module "backend_sg" {
    source = "git::https://github.com/lakshmimungara/terraform-aws-security-group.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    sg_name = "backend"
    vpc_id = local.vpc_id 
    common_tags = var.common_tags
    sg_tags = var.backend_sg_tags
}

# SG for frontend
module "frontend_sg" {
    source = "git::https://github.com/lakshmimungara/terraform-aws-security-group.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    sg_name = "frontend"
    vpc_id = local.vpc_id 
    common_tags = var.common_tags
    sg_tags = var.frontend_sg_tags
}

# SG for bastion 
# -> we will keep this bastion server in public server 
# -> we will connect to bastion and then we can able to connect to backend or database or frontend 
# -> so, this is called jump server 
# -> It's like a ec2 instance, it is in expense network so, it can connect to any server 
# -> we have to allow security group for bastion also 
# -> employess will connect to bastion to access the servers 
module "bastion_sg" {
    source = "git::https://github.com/lakshmimungara/terraform-aws-security-group.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    sg_name = "bastion"
    vpc_id = local.vpc_id 
    common_tags = var.common_tags
    sg_tags = var.bastion_sg_tags
}

module "ansible_sg" {
    source = "git::https://github.com/lakshmimungara/terraform-aws-security-group.git?ref=main"
    project_name = var.project_name
    environment = var.environment
    sg_name = "ansible"
    vpc_id = local.vpc_id 
    common_tags = var.common_tags
    sg_tags = var.ansible_sg_tags
}

# Mysql allowing connections on 3306 from the instances attached to backend security group 
# mysql --> backend
resource "aws_security_group_rule" "mysql_backend"{
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 3306 # calling port number 3306 for mysql
    to_port  = 3306
    protocol = "tcp"
    source_security_group_id  = module.backend_sg.id   # accept connections to this source
    security_group_id = module.mysql_sg.id  # to which security_group we are assigning the rule
}

# backend --> frontened 
resource "aws_security_group_rule" "backend_frontend"{
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 8080 
    to_port  = 8080
    protocol = "tcp"
    source_security_group_id  = module.frontend_sg.id   # accept connections to this source
    security_group_id = module.backend_sg.id  # to which security_group we are assigning the rule
}

# frontend --> public 
resource "aws_security_group_rule" "frontend_public"{
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 80
    to_port  = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
    security_group_id = module.frontend_sg.id # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "mysql_bastion"{  #mysql is accepting connections from bastion 
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.bastion_sg.id   # accept connections to this source
    security_group_id = module.mysql_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "backend_bastion"{  # backend is accepting connections from bastion 
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.bastion_sg.id   # accept connections to this source
    security_group_id = module.backend_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "frontend_bastion"{  # frontend is accepting connections from bastion 
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.bastion_sg.id   # accept connections to this source
    security_group_id = module.frontend_sg.id  # to which security_group we are assigning the rule
}

# ansible server 
resource "aws_security_group_rule" "mysql_ansible"{  #mysql is accepting connections from ansible
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.ansible_sg.id   # accept connections to this source
    security_group_id = module.mysql_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "backend_ansible"{  # backend is accepting connections from ansible 
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.ansible_sg.id   # accept connections to this source
    security_group_id = module.backend_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "frontend_ansible"{  # frontend is accepting connections from ansible 
    type  = "ingress"   # we are passing ingress rules 
    from_port  = 22 
    to_port  = 22
    protocol = "tcp"
    source_security_group_id  = module.ansible_sg.id   # accept connections to this source
    security_group_id = module.frontend_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "ansible_public"{  
    type  = "ingress"   # we are passing ingress rules 
    from_port  =  22 
    to_port  =  22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.ansible_sg.id  # to which security_group we are assigning the rule
}

resource "aws_security_group_rule" "bastion_public"{  
    type  = "ingress"   # we are passing ingress rules 
    from_port  =  22 
    to_port  =  22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.bastion_sg.id  # to which security_group we are assigning the rule
}