terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = "AKIA6GBMBMPYZI4GTOWJ"
  secret_key = "....."
}

resource "aws_vpc" "dev1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev1"
  }
}

resource "aws_internet_gateway" "dev1" {
  vpc_id = aws_vpc.dev1.id
}

resource "aws_route_table" "dev1-route_table" {
  vpc_id = aws_vpc.dev1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev1.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.dev1.id
  }

  tags = {
    Name = "dev1"
  }
}

resource "aws_subnet" "dev1-aws_subnet" {
  vpc_id = aws_vpc.dev1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "dev1"
  }
}

resource "aws_route_table_association" "dev1-route-assocication" {
  subnet_id = aws_subnet.dev1-aws_subnet.id
  route_table_id = aws_route_table.dev1-route_table.id
}

resource "aws_security_group" "dev1-access" {
  name = "Web_traffic_allowance"
  description = "Allow web traffic"
  vpc_id = aws_vpc.dev1.id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev1"
  }
}

resource "aws_network_interface" "dev1-nic" {
  subnet_id = aws_subnet.dev1-aws_subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.dev1-access.id]
}

resource "aws_eip" "dev1" {
  vpc = true
  network_interface = aws_network_interface.dev1-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.dev1]
}

resource "aws_instance" "dev1_instance" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "dev-key-1"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.dev1-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo dev1 web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "dev1"
  }
}