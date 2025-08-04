
## S3 

resource "aws_s3_bucket" "s3" {
  bucket = "ysolom-portfolio"
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.s3.id
  key          = "index.html"
  source       = "/Users/ys/Desktop/Coderco/project-portfolio/index.html"
  content_type = "text/html"
  etag         = filemd5("/Users/ys/Desktop/Coderco/project-portfolio/index.html")
}

resource "aws_s3_object" "resume" {
  bucket       = aws_s3_bucket.s3.id
  key          = "ys2025.pdf" 
  source       = "/Users/ys/Desktop/Coderco/project-portfolio/ys2025.pdf"
  content_type = "application/pdf"
  etag         = filemd5("/Users/ys/Desktop/Coderco/project-portfolio/ys2025.pdf")
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "s3" {
  bucket = aws_s3_bucket.s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "s3_bucket" {
  bucket = aws_s3_bucket.s3.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFront"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_dist.arn
          }
        }
      }
    ]
  })
}


## CLOUDFRONT

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "s3-cloudfront-oac"
  description                       = "Grant cloudfront access to s3 bucket ${aws_s3_bucket.s3.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

}

locals {
  s3_origin_id = "S3-ysolom-portfolio"
}

resource "aws_cloudfront_distribution" "s3_dist" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["www.ysolomprojects.co.uk", "ysolomprojects.co.uk"]

  origin {
    domain_name              = aws_s3_bucket.s3.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = local.s3_origin_id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.check.certificate_arn
    ssl_support_method  = "sni-only"

  }

  depends_on = [aws_acm_certificate_validation.check]
}

## ROUTE 53

data "aws_route53_zone" "hosted" {
  name = "ysolomprojects.co.uk"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hosted.zone_id
  name    = "www.ysolomprojects.co.uk"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_dist.domain_name
    zone_id                = aws_cloudfront_distribution.s3_dist.hosted_zone_id
    evaluate_target_health = false
  }

}

resource "aws_route53_record" "redirect" {
  zone_id = data.aws_route53_zone.hosted.zone_id
  name    = "ysolomprojects.co.uk"
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
  domain_name               = "ysolomprojects.co.uk"
  validation_method         = "DNS"
  subject_alternative_names = ["www.ysolomprojects.co.uk"]
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


