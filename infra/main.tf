provider "aws" {
  region = var.region
}

locals {
  az_names        = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets  = { for index, az in local.az_names : az => cidrsubnet(aws_vpc.image_pipeline_vpc.cidr_block, 8, index) }
  private_subnets = { for index, az in local.az_names : az => cidrsubnet(aws_vpc.image_pipeline_vpc.cidr_block, 8, index + 8) }
}

data "aws_availability_zones" "available" {
  region = var.region
  state  = "available"
}

resource "aws_vpc" "image_pipeline_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Image Pipeline VPC"
  }
}

resource "aws_subnet" "public" {
  for_each          = local.public_subnets
  vpc_id            = aws_vpc.image_pipeline_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "Public subnet ${each.value}"
  }
}

resource "aws_subnet" "private" {
  for_each          = local.private_subnets
  vpc_id            = aws_vpc.image_pipeline_vpc.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "Private subnet ${each.value}"
  }
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

resource "aws_s3_bucket_notification" "images_s3_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    events        = ["s3:ObjectCreated:Put"]
    queue_arn     = aws_sqs_queue.create_thumbnail.arn
    filter_prefix = "${var.raw_bucket_prefix}/"
  }
}