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

resource "aws_iam_role" "lambda_create_thumbnail" {
  name = "lambda_create_thumbnail"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_create_thumbnail.name
}

resource "aws_iam_role_policy" "lambda_create_thumbnail_bucket_queue" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.create_thumbnail.arn
      }
    ]
  })
  role = aws_iam_role.lambda_create_thumbnail.name
}

data "archive_file" "lambda_create_thumbnail" {
  source_dir = "${path.module}/../lambda/create_thumbnail"
  output_path = "${path.module}/lambda_create_thumbnail.zip"
  type        = "zip"
}

resource "aws_lambda_function" "create_thumbnail" {
  function_name = "create_thumbnail"
  role          = aws_iam_role.lambda_create_thumbnail.arn

  filename = data.archive_file.lambda_create_thumbnail.output_path
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_create_thumbnail.output_base64sha256
  runtime = "nodejs20.x"
  memory_size = 512
}

resource "aws_sqs_queue" "create_thumbnail" {
  name   = "create_thumbnail"
}

resource "aws_s3_bucket" "images" {
  bucket = "guikaua12-image-pipeline-s3-images-bucket"
}

resource "aws_lambda_event_source_mapping" "lambda_create_thumbnail_sqs" {
  event_source_arn = aws_sqs_queue.create_thumbnail.arn
  function_name = aws_lambda_function.create_thumbnail.function_name
  batch_size = 10
}