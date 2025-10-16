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

resource "aws_iam_role" "lambda_upload" {
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
  role       = aws_iam_role.lambda_upload.name
}

resource "aws_iam_role_policy" "lambda_upload_s3" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
  role = aws_iam_role.lambda_upload.name
}

data "archive_file" "lambda_upload" {
  source_dir  = "${path.module}/../lambda/create_thumbnail/dist"
  output_path = "${path.module}/lambda_create_thumbnail.zip"
  type        = "zip"
}

resource "aws_lambda_function" "upload" {
  function_name = "upload"
  role          = aws_iam_role.lambda_upload.arn

  filename = data.archive_file.lambda_upload.output_path
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_upload.output_base64sha256
  runtime = "nodejs20.x"
  memory_size = 512

  environment {
    variables = {
      "BUCKET_NAME" = aws_s3_bucket.images.bucket
    }
  }
}

resource "aws_sqs_queue" "create_thumbnail" {
  name   = "create_thumbnail"
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
    events = ["s3:ObjectCreated:Put"]
    queue_arn = aws_sqs_queue.create_thumbnail.arn
    filter_prefix = "uploads/"
  }
}

resource "aws_lambda_permission" "upload" {
  statement_id = "AllowLambdaUploadInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.image_upload.execution_arn}/*"
}