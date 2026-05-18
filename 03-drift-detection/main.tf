terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # Region comes from AWS_REGION / AWS_DEFAULT_REGION or aws configure
}

# Many accounts have no default VPC; SGs must be attached to a VPC explicitly.
resource "aws_vpc" "lab" {
  cidr_block = "10.42.0.0/16"

  tags = {
    Name = "devops-lab-drift-demo"
  }
}

resource "aws_security_group" "demo" {
  name        = "devops-lab-drift-demo"
  description = "Drift detection demo - safe to delete"
  vpc_id      = aws_vpc.lab.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-lab-drift-demo"
  }
}

output "security_group_id" {
  value = aws_security_group.demo.id
}
