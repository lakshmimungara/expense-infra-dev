locals {
  resource_name = "${var.project_name}-${var.environment}-bastion" # expense-dev-bastion
  bastion_sg_id = data.aws_ssm_parameter.bastion_sg_id.value
  #  this is the ssm_parameter --> /expense/dev/bastion_sg_id
  # And the value for it is sg-0b1fbde3c37bc5af2 (this we can find in AWS -> systems manager 
  # -> paramater store -> in /expense/dev/bastion_sg_id)
  public_subnet_id = split(",", data.aws_ssm_parameter.public_subnet_ids.value)[0]
  # it splits the public_subnet_id eg., subnet-1,subnet-2 --> ["subnet-1","subnet-2"] --> subnet[0]
  # subnet-0e32b43ee2a08c298,subnet-09bcf6611ee998f3f  --> ["subnet-0e32b43ee2a08c298","subnet-09bcf6611ee998f3f"] 
  # we only need first index value --> subnet-0e32b43ee2a08c298
}