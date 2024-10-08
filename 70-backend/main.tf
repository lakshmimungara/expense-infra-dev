# Step1:  backend instance creation 
module "backend" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.joindevops.id # we have declared this in data.tf file 
  name                   = local.resource_name        # expense-dev-backend
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.backend_sg_id]
  subnet_id              = local.private_subnet_id
  tags = merge(
    var.common_tags,
    var.backend_tags,
    {
      Name = local.resource_name # expense-dev-backend
    }

  )
}


# Step-2: Configuring backend instance with ansible 
resource "null_resource" "backend" {
  # Changes to any instance of the cluster requires re-provisioning 
  triggers = {
    instance_id = module.backend.id
  }

  # Bootstrap script can run on any instance of the cluster 
  # So we just choose the first in this case 
  connection {
    host = module.backend.private_ip
    # vpn is mandatory and without vpn we cannot connect to backend instance
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "${var.backend_tags.Component}.sh"  # backend.sh
    destination = "/tmp/backend.sh"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster 
    inline = [
      "chmod +x /tmp/backend.sh",
      "sudo sh /tmp/backend.sh ${var.backend_tags.Component} ${var.environment}" 
    ]
  }
}

  # Step-3: Stopping the backend instance 
    resource "aws_ec2_instance_state" "backend" {
    instance_id = module.backend.id
    state       = "stopped"
    depends_on = [null_resource.backend]
  }

  # Step-4: Taking the AMI image
  resource "aws_ami_from_instance" "backend" {
    name               = local.resource_name
    source_instance_id = module.backend.id
    depends_on = [aws_ec2_instance_state.backend]
  }

  # Step-5: deleting the backend instance
  resource "null_resource" "backend_delete" {
    # Changes to any instance of the cluster requires re-provisioning
    triggers = {
      instance_id = module.backend.id
    }

    provisioner "local-exec" {
      command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"
    }

    depends_on = [aws_ami_from_instance.backend]
  }

  # Step-6: Creating target group 
  resource "aws_lb_target_group" "backend" {
  name     = local.resource_name
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    healthy_threshold = 2   # on continuous hit of two success thresholds are healthy
    unhealthy_threshold = 2  #  on continuous hit of two failure thresholds are unhealthy
    interval = 5    # just like a speed 
    matcher = "200-299"   # success code from 200-299
    path = "/health"      # path 
    port = 8080           
    protocol = "HTTP"
    timeout = 4    # in default 30 seconds 
  }
}

# Step-7: Launch Template
resource "aws_launch_template" "backend" {

  name = local.resource_name
  image_id = aws_ami_from_instance.backend.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  
  update_default_version = true   # it updates the version everytime 
  vpc_security_group_ids = [local.backend_sg_id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name
    }
  }
}

# Step-8: Creation of autoscaling group 
resource "aws_autoscaling_group" "backend" {
  name                      = local.resource_name
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2 # starting of the auto scaling group
  #force_delete              = true
  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [local.private_subnet_id]

  tag {
    key                 = "Name"
    value               = local.resource_name
    propagate_at_launch = true
  }

  # If instances are not healthy with in 15min, autoscaling will delete that instance
  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Project"
    value               = "Expense"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "example" {
  name = local.resource_name
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name  = aws_autoscaling_group.backend.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}