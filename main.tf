provider "aws" {
  region = "ap-south-1"
  access_key = "AKIAZI2LGSGNSKGLMUYE"
  secret_key = "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"
}

# 1. Create a VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# 2. Create an Internet Gatewat

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production"
  }
}

# 3. Create a custom Route Table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0" #This will send all the IPv4 traffic to whereever this route points.
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "production"
  }
}

# 4. Create a Subnet

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet"
  }
}

# 5. Associate Subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create Security Group to allow port 22, 80, 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web-traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  tags = {
    Name = "allow_web"
  }
}


resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  description = "HTTPS"
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0" 
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  description = "HTTP"
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  description = "SSH"
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# 7. Create a Network Interface with an IP in the Subnet that was create in Step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.1.50"] #Here we can pass list of IP's
  security_groups = [aws_security_group.allow_web.id]
}
# 8. Assign an Elastic IP to the Network Interface create in step 7

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_instance.web-server-instance ]
}

# 9. Create an Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami = "ami-0ad21ae1d0696ad58"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id

  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server"
  }
}