# main.tf

provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

# Fetch the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]  # Canonical
}

# Import your SSH public key
resource "aws_key_pair" "deployer" {
  key_name   = "ubuntu_aws_key"
  public_key = file("${path.module}/ubuntu_aws.pub")
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group to allow SSH access
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For security, consider restricting to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "ubuntu_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"  # Free-tier eligible
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "Ubuntu-Free-Tier"
  }
}

# Output the public IP
output "instance_ip" {
  value = aws_instance.ubuntu_instance.public_ip
}
