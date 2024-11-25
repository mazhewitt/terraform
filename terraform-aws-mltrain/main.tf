# Terraform version and required provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Input variables
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "sagemaker_role_name" {
  description = "Name for the SageMaker execution role"
  type        = string
}

variable "notebook_instance_name" {
  description = "Name for the SageMaker notebook instance"
  type        = string
}

# Create an IAM role for SageMaker
resource "aws_iam_role" "sagemaker_execution_role" {
  name = var.sagemaker_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "sagemaker_policy_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Define the allowed IP as a variable
variable "allowed_ip" {
  description = "The IP address allowed to access the SageMaker notebook"
  type        = string
}

# Security group for the notebook instance
resource "aws_security_group" "sagemaker_sg" {
  name        = "sagemaker-notebook-sg"
  description = "Allow SageMaker notebook traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  vpc_id = data.aws_vpc.default.id

  # Replace with your preferred availability zone
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"]
  }
}

# Update the SageMaker notebook instance
resource "aws_sagemaker_notebook_instance" "ml_notebook" {
  name              = var.notebook_instance_name
  instance_type     = "ml.t3.medium"
  role_arn          = aws_iam_role.sagemaker_execution_role.arn
  security_groups   = [aws_security_group.sagemaker_sg.id]
  subnet_id         = data.aws_subnet.default.id

  tags = {
    Name = "ML Notebook"
  }
}

# Output the notebook URL
output "notebook_url" {
  value = aws_sagemaker_notebook_instance.ml_notebook.url
}

# Output the role ARN
output "sagemaker_execution_role_arn" {
  value = aws_iam_role.sagemaker_execution_role.arn
}
