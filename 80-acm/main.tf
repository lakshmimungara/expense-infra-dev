# Requesting for ACM certificate
resource "aws_acm_certificate" "expense"{
    # The aws_acm_certificate resource is used to request a new SSL/TLS certificate for the domain.
    domain_name = "*.${var.zone_name}"  
    /*For example, if var.zone_name is daws81s.fun, 
    this will cover *.daws81s.fun (e.g., app.daws81s.fun, api.daws81s.fun, etc.).*/
    validation_method = "DNS"

    tags = merge(
        var.common_tags,
        {
            Name = local.resource_name    # expense-dev 
        }
    )
}


# Creating DNS records for validation
resource "aws_route53_record" "expense" {
  for_each = {
    /*
    The for_each statement dynamically creates DNS records based on ACM's domain validation options. 
    These options are provided by AWS ACM after requesting the certificate.
    */
    for dvo in aws_acm_certificate.expense.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}


# Validating the ACM certificate 
/*
Once the DNS records are created, AWS ACM waits for DNS validation. 
The aws_acm_certificate_validation resource handles this process.
*/
resource "aws_acm_certificate_validation" "expense" {
  certificate_arn         = aws_acm_certificate.expense.arn
  validation_record_fqdns = [for record in aws_route53_record.expense : record.fqdn]
}
