/*
Step 1: Creates a backend EC2 instance using a pre-configured Terraform module.
Step 2: Configures the backend instance using Ansible and Shell scripting with the null_resource and provisioners.
Step 3: Stops the backend instance.
Step 4: Takes an AMI image of the stopped backend instance.
Step 5: Terminates/delete the backend instance.
Step 6: Creates a Target Group for load balancing backend instances.
Step 7: Creates a Launch Template for launching backend instances with the AMI.
Step 8: Creates an Auto Scaling Group to manage and scale the backend instances.
*/


# Step1:  backend instance creation 
module "backend" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.joindevops.id # we have declared this in data.tf file 
  name                   = local.resource_name        # expense-dev-backend
  instance_type          = "t3.micro"   # Instance Type: Defines the instance as t3.micro.
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
    /*Uses SSH to connect to the backend instance. 
    The connection uses the private IP address with a user and password.*/
    # vpn is mandatory and without vpn we cannot connect to backend instance
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "${var.backend_tags.Component}.sh"  # backend.sh
    destination = "/tmp/backend.sh"  # Uploads a shell script (backend.sh) to the instance at /tmp/backend.sh.
  }

  provisioner "remote-exec" {
    /*Executes the shell script to configure the backend instance. 
    It passes the component and environment variables to the script.*/
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
    state       = "stopped"  # The state of the instance is set to "stopped" after the configuration.
    depends_on = [null_resource.backend] 
    # Ensures the instance is only stopped after the configuration completes.
  }

  # Step-4: Taking the AMI image
  resource "aws_ami_from_instance" "backend" {
    # This creates an AMI from the stopped backend instance so that it can be used later to launch new instances.
    name               = local.resource_name  # expense-dev-backend
    source_instance_id = module.backend.id
    depends_on = [aws_ec2_instance_state.backend]  
    # Ensures that the AMI is created only after the instance is stopped.
  }

  # Step-5: deleting the backend instance
  resource "null_resource" "backend_delete" {
    # Changes to any instance of the cluster requires re-provisioning
    triggers = {
      instance_id = module.backend.id
    }

    provisioner "local-exec" {
      # Uses a local-exec provisioner to run an AWS CLI command to terminate the EC2 instance.
      command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"
    }

    depends_on = [aws_ami_from_instance.backend]  
    #Ensures the instance is deleted only after the AMI creation.
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
    timeout = 4    # by default 30 seconds 
  }
}

# Step-7: Launch Template
resource "aws_launch_template" "backend" {
  /*Specifies how EC2 instances should be launched 
  using the created AMI and instance configurations (instance type, security groups, etc.).*/
  name = local.resource_name  # expense-dev-backend
  image_id = aws_ami_from_instance.backend.id
  instance_initiated_shutdown_behavior = "terminate"  
  # Ensures the instance is terminated on shutdown
  instance_type = "t3.micro"
  
  update_default_version = true   # it updates the version everytime 
  vpc_security_group_ids = [local.backend_sg_id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name  # expense-dev-backend
    }
  }
}

# Step-8: Creation of autoscaling group 
resource "aws_autoscaling_group" "backend" {
  name                      = local.resource_name   # expense-dev-backend
  #  Automatically scales instances based on demand (min 2 instances, max 10).
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2 # starting of the auto scaling group
  #force_delete              = true
  target_group_arns          = [aws_lb_target_group.backend.arn]
  launch_template {
    id      = aws_launch_template.backend.id    # Here, we are taking launch template id 
    version = "$Latest"
  }
  vpc_zone_identifier       = [local.private_subnet_id]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = local.resource_name   # expense-dev-backend
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
  name = local.resource_name   # expense-dev-backend
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name  = aws_autoscaling_group.backend.name   # expense-dev-backend
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0   # When CPU utilization exceeds 70%, new instances are launched.
  }
}

# Step-9: Listener rule 
resource "aws_lb_listener_rule" "backend" {
  listener_arn = local.app_alb_listener_arn
  priority     = 100 # low priority will be evaluated first

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    host_header {
      values = ["${var.backend_tags.Component}.app-${var.environment}.${var.zone_name}"]
      # backend.app-dev.daws81s.fun 
    }
  }
}