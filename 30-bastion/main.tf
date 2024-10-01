module "bastion"{
    source = "terraform-aws-modules/ec2-instance/aws"
    ami = data.aws_ami.joindevops.id   # we have declared this in data.tf file 
    name = local.resource_name   # expense-dev-bastion
    instance_type  = "t3.micro"
    vpc_security_group_ids = [local.bastion_sg_id] 
    # And the value for it is sg-0b1fbde3c37bc5af2 (this we can find in AWS -> systems manager 
    # -> paramater store -> in /expense/dev/bastion_sg_id)
    subnet_id  = local.public_subnet_id   # subnet-0e32b43ee2a08c298

    tags = merge(
        var.common_tags,
        var.bastion_tags,
        {
            Name = local.resource_name  # expense-dev-bastion
        }

    )
}