resource "aws_api_gateway_rest_api" "image_upload" {
  name = "image_upload_api"
}

resource "aws_api_gateway_resource" "images" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  parent_id   = aws_api_gateway_rest_api.image_upload.root_resource_id
  path_part   = "images"
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "upload"
}

resource "aws_api_gateway_resource" "presign" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  parent_id   = aws_api_gateway_resource.upload.id
  path_part   = "presign"
}

resource "aws_api_gateway_method" "upload" {
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  resource_id   = aws_api_gateway_resource.presign.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload" {
  rest_api_id             = aws_api_gateway_rest_api.image_upload.id
  resource_id             = aws_api_gateway_resource.presign.id
  http_method             = aws_api_gateway_method.upload.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload.invoke_arn
}

resource "aws_api_gateway_deployment" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.upload.id,
      aws_api_gateway_method.upload.id,
      aws_api_gateway_resource.images.id,
      aws_api_gateway_resource.upload.id,
      aws_api_gateway_resource.presign.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.upload.id
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  stage_name    = "prod"
}