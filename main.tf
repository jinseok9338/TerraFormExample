provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAJAIEHOKODFBWFPAQ"
  secret_key = "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"
}



resource "aws_vpc" "prod_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "production"
  }
}

#internet Gateway
resource "aws_internet_gateway" "prod_internet_gateway" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod_internet_gateway"
  }
}

#Set up Route Table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_internet_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod_internet_gateway.id
  }

  tags = {
    Name = "prod_route_table"
  }
}

#create Subnet

resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}


#associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.prod_route_table.id
}

#Create Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_WEB"
  }
}

#Create NetWork Interface
resource "aws_network_interface" "web_server_NIF" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#Assign an EIP to the NIF 
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_NIF.id
  associate_with_private_ip = "10.0.0.50"
  depends_on                = [aws_internet_gateway.prod_internet_gateway] #Reference not just an id but the whole object
}

#Create Instance
resource "aws_instance" "web_server_instance" {
  ami               = "ami-042e8287309f5df03"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "mainKey"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_NIF.id
  }

  user_data = <<-EOF
#!bin/bash
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo bash -c 'echo your first web server > /var/www/html/index.html'
EOF
  tags = {
    Name = "web_server"
  }
}
