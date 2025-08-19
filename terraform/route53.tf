
data "aws_route53_zone" "hosted" {
  name = var.domain
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hosted.zone_id
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_dist.domain_name
    zone_id                = aws_cloudfront_distribution.s3_dist.hosted_zone_id
    evaluate_target_health = false
  }

}

resource "aws_route53_record" "redirect" {
  zone_id = data.aws_route53_zone.hosted.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_dist.domain_name
    zone_id                = aws_cloudfront_distribution.s3_dist.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "valid" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.hosted.zone_id
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain
  validation_method         = "DNS"
  subject_alternative_names = ["www.${var.domain}"]
  provider                  = aws.us_east_1

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "check" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.valid : record.fqdn]
}


