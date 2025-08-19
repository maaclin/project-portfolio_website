


## CLOUDFRONT

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = var.oac
  description                       = "Grant cloudfront access to s3 bucket ${aws_s3_bucket.s3.id}"
  
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

}


resource "aws_cloudfront_distribution" "s3_dist" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["www.${var.domain}", var.domain]

  origin {
    domain_name              = aws_s3_bucket.s3.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = var.s3_id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.s3_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = var.redirect
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