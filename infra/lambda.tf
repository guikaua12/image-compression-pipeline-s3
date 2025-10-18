// upload lambda
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

resource "aws_iam_role_policy_attachment" "lambda_upload_basic_execution" {
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

  filename         = data.archive_file.lambda_upload.output_path
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_upload.output_base64sha256
  runtime          = "nodejs20.x"
  memory_size      = 512

  environment {
    variables = {
      "BUCKET_NAME"       = aws_s3_bucket.images.bucket
      "RAW_BUCKET_PREFIX" = var.raw_bucket_prefix
    }
  }
}

resource "aws_lambda_permission" "upload" {
  statement_id  = "AllowLambdaUploadInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.image_upload.execution_arn}/*"
}

// image compression lambda
resource "aws_iam_role" "lambda_image_compression" {
  name = "lambda_image_compression"
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

resource "aws_iam_role_policy_attachment" "lambda_image_compression_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_image_compression.name
}

resource "aws_iam_role_policy" "lambda_image_compression" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = aws_sqs_queue.create_thumbnail.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.image_metadata.arn
      }
    ]
  })
  role = aws_iam_role.lambda_image_compression.name
}

data "archive_file" "lambda_image_compression" {
  source_dir  = "${path.module}/../lambda/image_compression"
  output_path = "${path.module}/lambda_image_compression.zip"
  type        = "zip"
  excludes    = ["tsconfig.json", "src", "*.ts", "**/node_modules/.bin/*"]
}

resource "aws_lambda_function" "image_compression" {
  function_name = "image_compression"
  role          = aws_iam_role.lambda_image_compression.arn

  filename         = data.archive_file.lambda_image_compression.output_path
  handler          = "dist/index.handler"
  source_code_hash = data.archive_file.lambda_image_compression.output_base64sha256
  runtime          = "nodejs20.x"
  memory_size      = 512
  architectures    = ["x86_64"]

  environment {
    variables = {
      "RAW_BUCKET_PREFIX"        = var.raw_bucket_prefix
      "COMPRESSED_BUCKET_PREFIX" = var.compressed_bucket_prefix
      "DYNAMODB_TABLE_NAME"      = aws_dynamodb_table.image_metadata.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "lambda_image_compression_sqs" {
  function_name    = aws_lambda_function.image_compression.function_name
  event_source_arn = aws_sqs_queue.create_thumbnail.arn
  batch_size       = 10
}
