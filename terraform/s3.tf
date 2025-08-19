
resource "aws_s3_bucket" "s3" {
  bucket = var.bucket
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
  depends_on = [aws_cloudfront_distribution.s3_dist]
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
