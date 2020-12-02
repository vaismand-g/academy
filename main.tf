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
    User = "Damian Vaisman"
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
    User = "Damian Vaisman"
  }
}

resource "aws_subnet" "dv-subnet-pub-east1b-terra" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.dv-vpc-terra.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "dv-subnet-pub-east1b-terra"
    User = "Damian Vaisman"
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
  subnet_id      = "dv-subnet-pub-east1a-terra"
  route_table_id = aws_route_table.dv-subnet-pub-terra.id
}

resource "aws_route_table_association" "dv-asoc-rt-to-subn2" {
  subnet_id      = "dv-subnet-pub-east1b-terra"
  route_table_id = aws_route_table.dv-subnet-pub-terra.id
}

resource "aws_security_group" "dv-sg-ec2-8080-terra" {
  name = "dv-sg-ec2-8080-terra"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    User = "Damian Vaisman"
  }
}

resource "aws_security_group" "dv-sg-elb-80-terra" {
  name = "dv-sg-elb-80-terra"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    security_groups = [aws_security_group.dv-sg-ec2-8080-terra.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "test"
      User = "Damian Vaisman"
    }
  }

  user_data = file("install_apache.sh")
}

data "aws_availability_zones" "all" {}


resource "aws_elb" "dv-elb-terra" {
  name               = "dv-elb-terra"
  security_groups    = [aws_security_group.dv-sg-elb-80-terra.id]
  availability_zones = data.aws_availability_zones.all.names
  health_check {
    target              = "HTTP:8080/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Adding a listener for incoming HTTP requests.
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 8080
    instance_protocol = "http"
  }
}

resource "aws_autoscaling_group" "dv-scalegrp-terra" {
  max_size = 4
  min_size = 0
  desired_capacity = 0
  launch_template {
    name = aws_launch_template.dv-launchtemplate-terraf.id
    version = "$Latest"
  }
  #availability_zones = [data.aws_availability_zones.all.names]
  vpc_zone_identifier = [aws_subnet.dv-subnet-pub-east1a-terra.id,aws_subnet.dv-subnet-pub-east1b-terra.id]
  load_balancers = [aws_elb.dv-elb-terra.id]
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "dv-scalegrp-terra"
    propagate_at_launch = true
  }
}

# added comments - pending ask Homero
#output "elb_dns_name" {
#  value       = aws_elb.sample.dns_name
#  description = "The domain name of the load balancer"
#}