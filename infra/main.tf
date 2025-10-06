provider "aws" {
  region = var.region
}

resource "aws_vpc" "image_pipeline_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Image Pipeline VPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.image_pipeline_vpc.id
  cidr_block = "10.0.1.0/24"
  region = var.region

  tags = {
    Name = "Public subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.image_pipeline_vpc.id
  cidr_block = "10.0.2.0/24"
  region = var.region

  tags = {
    Name = "Private subnet"
  }
}