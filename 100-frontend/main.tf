/*
Step 1: Creates a frontend EC2 instance using a pre-configured Terraform module.
Step 2: Configures the frontend instance using Ansible and Shell scripting with the null_resource and provisioners.
Step 3: Stops the frontend instance.
Step 4: Takes an AMI image of the stopped frontend instance.
Step 5: Terminates/delete the frontend instance.
Step 6: Creates a Target Group for load balancing frontend instances.
Step 7: Creates a Launch Template for launching frontend instances with the AMI.
Step 8: Creates an Auto Scaling Group to manage and scale the frontend instances.
*/


# Step1:  frontend instance creation 
module "frontend" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.joindevops.id # we have declared this in data.tf file 
  name                   = local.resource_name        # expense-dev-frontend
  instance_type          = "t3.micro"   # Instance Type: Defines the instance as t3.micro.
  vpc_security_group_ids = [local.frontend_sg_id]
  subnet_id              = local.public_subnet_id
  tags = merge(
    var.common_tags,
    var.frontend_tags,
    {
      Name = local.resource_name # expense-dev-frontend
    }

  )
}


# Step-2: Configuring frontend instance with ansible 
resource "null_resource" "frontend" {
  # Changes to any instance of the cluster requires re-provisioning 
  triggers = {
    instance_id = module.frontend.id
  }

  # Bootstrap script can run on any instance of the cluster 
  # So we just choose the first in this case 
  connection {
    host = module.frontend.private_ip
    /*Uses SSH to connect to the frontend instance. 
    The connection uses the private IP address with a user and password.*/
    # vpn is mandatory and without vpn we cannot connect to frontend instance
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "${var.frontend_tags.Component}.sh"  # frontend.sh
    destination = "/tmp/frontend.sh"  # Uploads a shell script (frontend.sh) to the instance at /tmp/frontend.sh.
  }

  provisioner "remote-exec" {
    /*Executes the shell script to configure the frontend instance. 
    It passes the component and environment variables to the script.*/
    # Bootstrap script called with private_ip of each node in the cluster 
    inline = [
      "chmod +x /tmp/frontend.sh",
      "sudo sh /tmp/frontend.sh ${var.frontend_tags.Component} ${var.environment}" 
    ]
  }
}

  # Step-3: Stopping the frontend instance 
    resource "aws_ec2_instance_state" "frontend" {
    instance_id = module.frontend.id
    state       = "stopped"  # The state of the instance is set to "stopped" after the configuration.
    depends_on = [null_resource.frontend] 
    # Ensures the instance is only stopped after the configuration completes.
  }

  # Step-4: Taking the AMI image
  resource "aws_ami_from_instance" "frontend" {
    # This creates an AMI from the stopped frontend instance so that it can be used later to launch new instances.
    name               = local.resource_name  # expense-dev-frontend
    source_instance_id = module.frontend.id
    depends_on = [aws_ec2_instance_state.frontend]  
    # Ensures that the AMI is created only after the instance is stopped.
  }

  # Step-5: deleting the frontend instance
  resource "null_resource" "frontend_delete" {
    # Changes to any instance of the cluster requires re-provisioning
    triggers = {
      instance_id = module.frontend.id
    }

    provisioner "local-exec" {
      # Uses a local-exec provisioner to run an AWS CLI command to terminate the EC2 instance.
      command = "aws ec2 terminate-instances --instance-ids ${module.frontend.id}"
    }

    depends_on = [aws_ami_from_instance.frontend]  
    #Ensures the instance is deleted only after the AMI creation.
  }

  # Step-6: Creating target group 
  resource "aws_lb_target_group" "frontend" {
  name     = local.resource_name
  port     = 80
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
    timeout = 4    # by default 30 seconds 
  }
}

# Step-7: Launch Template
resource "aws_launch_template" "frontend" {
  /*Specifies how EC2 instances should be launched 
  using the created AMI and instance configurations (instance type, security groups, etc.).*/
  name = local.resource_name  # expense-dev-frontend
  image_id = aws_ami_from_instance.frontend.id
  instance_initiated_shutdown_behavior = "terminate"  
  # Ensures the instance is terminated on shutdown
  instance_type = "t3.micro"
  
  update_default_version = true   # it updates the version everytime 
  vpc_security_group_ids = [local.frontend_sg_id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name  # expense-dev-frontend
    }
  }
}

# Step-8: Creation of autoscaling group 
resource "aws_autoscaling_group" "frontend" {
  name                      = local.resource_name   # expense-dev-frontend
  #  Automatically scales instances based on demand (min 2 instances, max 10).
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2 # starting of the auto scaling group
  #force_delete              = true
  target_group_arns          = [aws_lb_target_group.frontend.arn]
  launch_template {
    id      = aws_launch_template.frontend.id    # Here, we are taking launch template id 
    version = "$Latest"
  }
  vpc_zone_identifier       = [local.public_subnet_id]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = local.resource_name   # expense-dev-frontend
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

# adding policy to the autoscaling group 
resource "aws_autoscaling_policy" "example" {
  name = local.resource_name   # expense-dev-frontend
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name  = aws_autoscaling_group.frontend.name   # expense-dev-frontend
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0   # When CPU utilization exceeds 70%, new instances are launched.
  }
}

# Step-9: Listener rule 
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = local.web_alb_listener_arn
  priority     = 100 # low priority will be evaluated first

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    host_header {
      values = ["expense-${var.environment}.${var.zone_name}"]
      # expense-dev.daws81s.fun 
    }
  }
}