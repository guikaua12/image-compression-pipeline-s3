resource "aws_dynamodb_table" "image_metadata" {
  name         = "image_metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "Image Metadata Table"
  }
}
