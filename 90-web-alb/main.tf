
# creating application load balancer(ALB)
module "web_alb" {
  source = "terraform-aws-modules/alb/aws"
  internal = false   # internal = false means that this is an external load balancer, publicly accessible over the internet.
  name    = "${local.resource_name}-web-alb"   # expense-dev-web-alb
  vpc_id  = local.vpc_id
  subnets = local.public_subnet_ids
  security_groups = [data.aws_ssm_parameter.web_alb_sg_id.value]
  create_security_group = false 
  enable_deletion_protection = false
  tags = merge(
    var.common_tags,
    var.web_alb_tags
  )
}


# target group  - creating listeners/rules
/*
The ALB is configured with two listeners, one for HTTP (port 80) 
and another for HTTPS (port 443):
*/
resource "aws_lb_listener" "http" {
  load_balancer_arn = module.web_alb.arn    # arn - amazon resourse name - which is unique 
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = module.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.https_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Hello, I am from Web ALB HTTPS</h1>"
      status_code  = "200"
    }
  }
}


# we are going to add records in Route53
module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"

  zone_name = var.zone_name #daws81s.fun
  records = [
    {
      name    = "expense-${var.environment}" # expense-dev.daws81s.fun
      type    = "A"
      alias   = {
        name    = module.web_alb.dns_name
        zone_id = module.web_alb.zone_id # Refers to the internal hosted zone for the ALB (module.web_alb.zone_id), not the public Route 53 zone
      }
      allow_overwrite = true   # It allows updating the DNS record if it already exists.
    }
  ]
}