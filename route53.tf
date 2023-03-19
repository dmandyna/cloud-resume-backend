resource "aws_route53_record" "validation" {
  for_each = {
    for entry in aws_acm_certificate.this.domain_validation_options : entry.domain_name => {
      name   = entry.resource_record_name
      record = entry.resource_record_value
      type   = entry.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
  lifecycle {
    ignore_changes = [
      name
    ]
  }
}

resource "aws_route53_record" "domain" {
  allow_overwrite = true
  name            = aws_apigatewayv2_domain_name.this.id
  type            = "A"
  zone_id         = data.aws_route53_zone.this.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
