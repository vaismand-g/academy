terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#create VPC
resource "aws_vpc" "dv-vpc-terra" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dv-vpc-terra"
    User = "damian.vaisman"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "dv_igw" {
  vpc_id = aws_vpc.dv-vpc-terra.id
}

resource "aws_subnet" "dv-subnet-pub-east1a-terra" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.dv-vpc-terra.id
  availability_zone = "us-east-1a"
  tags = {
    Name = "dv-subnet-pub-east1a-terra"
    User = "damian.vaisman"
  }
}

resource "aws_subnet" "dv-subnet-pub-east1b-terra" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.dv-vpc-terra.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "dv-subnet-pub-east1b-terra"
    User = "damian.vaisman"
  }
}

resource "aws_route_table" "dv-subnet-pub-terra" {
  vpc_id = aws_vpc.dv-vpc-terra.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dv_igw.id
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "dv-asoc-rt-to-subn1" {
  subnet_id      = aws_subnet.dv-subnet-pub-east1a-terra.id
  route_table_id = aws_route_table.dv-subnet-pub-terra.id
}

resource "aws_route_table_association" "dv-asoc-rt-to-subn2" {
  subnet_id      = aws_subnet.dv-subnet-pub-east1b-terra.id
  route_table_id = aws_route_table.dv-subnet-pub-terra.id
}

resource "aws_security_group" "dv-sg-terra" {
  name = "dv-sg-terra"
  description = "Allow HTTP/S inbound traffic"
  vpc_id = aws_vpc.dv-vpc-terra.id

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    name = "dv-sg-terra"
    User = "damian.vaisman"
  }
}

resource "aws_launch_template" "dv-launchtemplate-terraf" {
  name = "dv-launchtemplate-terraf"
  image_id = "ami-04d29b6f966df1537"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  key_name = "dv-keypair-terra"

  network_interfaces {
    associate_public_ip_address = true
    security_groups = aws_security_group.dv-sg-terra.id
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      User = "damian.vaisman"
    }
  }
  user_data = <<EOF
#! /bin/bash
sudo yum update
sudo yum install httpd -y
sudo systemctl start httpd
sudo systemctl stop firewalld
sudo echo "Hello World from $(hostname -f)" > /var/www/html/index.html
EOF
}

resource "aws_alb" "dv-alb-terra" {
  name = "dv-alb-terra"
  internal = false
  ip_address_type = "ipv4"
  security_groups = [aws_security_group.dv-sg-terra.id]
  subnets = [aws_subnet.dv-subnet-pub-east1b-terra, aws_subnet.dv-subnet-pub-east1a-terra]
  tags = {
    User = "damian.vaisman"
  }
}

resource "aws_alb_target_group" "dv-alb-target-group-terra" {
  name = "dv-alb-target-group-terra"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.dv-vpc-terra.id
  tags = {
    User = "damian.vaisman"
  }
}

resource "aws_alb_listener" "dv_alb_listener_terra" {
  load_balancer_arn = aws_alb.dv-alb-terra.id
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.dv-alb-target-group-terra.id
  }
}

resource "aws_autoscaling_group" "dv-as-group-terra" {
  name = "mb_as_group_terraform"
  vpc_zone_identifier = [aws_subnet.dv-subnet-pub-east1a-terra.id, aws_subnet.dv-subnet-pub-east1b-terra.id]
    launch_template {
    name = aws_launch_template.dv-launchtemplate-terraf.id
    version = "$Latest"
  }
  max_size = 4
  min_size = 0
  desired_capacity = 0
  target_group_arns = [aws_alb_target_group.dv-alb-target-group-terra.id]
  tag {
    key = "User"
    propagate_at_launch = true
    value = "damian.vaisman"
  }
}