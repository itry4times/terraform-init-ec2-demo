terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.25.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "region" {}
variable "access_key" {}
variable "secret_key" {}
variable "env_prefix" {}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "ec2_type" {}

variable "public_key_path" {}
# variable "image_id" {}

resource "aws_vpc" "test-vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "test-subnet" {
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone

  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}

resource "aws_route_table" "test-rtb" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw.id
  }

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

resource "aws_route_table_association" "test-ac-rtb-subnet" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-rtb.id
}

resource "aws_security_group" "test-sg" {
  name   = "test-sg"
  vpc_id = aws_vpc.test-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", ]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0", ]
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }

}

resource "aws_key_pair" "ssh-key" {
  key_name   = "secret-key"
  public_key = file(var.public_key_path)
}

# data "aws_ami" "lts-amazon-image" {
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
#     # amzn2-ami-kernel-5.10-hvm-2.0.20220719.0-x86_64-gp2
#     # amzn2-ami-hvm-2.0.20220719.0-x86_64-gp2
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# output "aws_ami_id" {
#   value = data.aws_ami.lts-amazon-image.id
# }

data "aws_ami" "lts-ubuntu-image" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.lts-ubuntu-image.id
}

resource "aws_instance" "test-ec2" {
  ami           = data.aws_ami.lts-ubuntu-image.id
  instance_type = var.ec2_type

  key_name                    = aws_key_pair.ssh-key.key_name
  associate_public_ip_address = true

  subnet_id              = aws_subnet.test-subnet.id
  vpc_security_group_ids = [aws_security_group.test-sg.id]
  availability_zone      = var.avail_zone

  #   user_data = <<EOF
  # #!/bin/bash
  # sudo apt update
  # sudo apt install docker.io -y
  # sudo usermod -aG docker ubuntu
  # mkdir testd
  # EOF

  tags = {
    Name = "${var.env_prefix}-ec2"
  }

  provisioner "local-exec" {
    command = templatefile("ssh-config.tpl", {
      hostname = "myec2"
      host_ip  = self.public_ip
      user     = "ubuntu"
      # identityfile = var.ssh_private_key
    })
  }
}

output "ec2-public-ip" {
  value = aws_instance.test-ec2.public_ip
}
