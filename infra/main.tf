provider "aws" {
  region = var.region
}

resource "aws_sqs_queue" "create_thumbnail" {
  name = "create_thumbnail"
}

resource "aws_sqs_queue_policy" "create_thumbnail_policy" {
  queue_url = aws_sqs_queue.create_thumbnail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.create_thumbnail.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.images.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "images" {
  bucket = "guikaua12-image-pipeline-s3-images-bucket"
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.images.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.images.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "images_s3_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    events        = ["s3:ObjectCreated:Put"]
    queue_arn     = aws_sqs_queue.create_thumbnail.arn
    filter_prefix = "${var.raw_bucket_prefix}/"
  }
}