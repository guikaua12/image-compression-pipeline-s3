resource "aws_api_gateway_rest_api" "image_upload" {
  name = "image_upload_api"
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  parent_id   = aws_api_gateway_rest_api.image_upload.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload" {
  rest_api_id   = aws_api_gateway_rest_api.image_upload.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = aws_lambda_function.create_thumbnail.invoke_arn
}

resource "aws_api_gateway_deployment" "upload" {
  rest_api_id = aws_api_gateway_rest_api.image_upload.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.upload.id,
      aws_api_gateway_method.upload.id,
      aws_api_gateway_resource.upload.id
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