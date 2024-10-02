
# creating application load balancer(ALB)
module "app_alb" {
  source = "terraform-aws-modules/alb/aws"
  internal = true 
  name    = "${local.resource_name}-app-alb"   # expense-dev-app-alb
  vpc_id  = local.vpc_id
  subnets = local.private_subnet_ids
  security_groups = [data.aws_ssm_parameter.app_alb_sg_id.value]
  create_security_group = false 
  # enable_deletion_protection = false
  tags = merge(
    var.common_tags,
    var.app_alb_tags
  )
}


# target group  - creating listeners/rules
resource "aws_lb_listener" "http" {
  load_balancer_arn = module.app_alb.arn    # arn - amazon resourse name - which is unique 
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Hello, I am from Application ALB</h1>"
      status_code  = "200"
    }
  }
}


# we are going to add records 
module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"

  zone_name = var.zone_name #daws81s.fun
  records = [
    {
      name    = "*.app-${var.environment}" # *.app-dev.daws81s.fun
      type    = "A"
      alias   = {
        name    = module.app_alb.dns_name
        zone_id = module.app_alb.zone_id # This belongs to ALB internal hosted zone, not ours
      }
      allow_overwrite = true
    }
  ]
}