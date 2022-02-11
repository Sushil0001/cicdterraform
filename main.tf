# Authentication to AWS from Terraform code 
provider "aws" {
    region = "ap-south-1"
    profile = "ram"
}
# Create a VPC in AWS part of region i.e. Mumbai 
resource "aws_vpc" "ram_vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true 

    tags = {
        Name = "ram_vpc"
        Created_By = "Terraform"
    }
}

# Create a Public-Subnet1 part of ram_vpc 
resource "aws_subnet" "ram_public_subnet1" {
    vpc_id = "${aws_vpc.ram_vpc.id}"     # 0.11.7 
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true 
    availability_zone = "ap-south-1a"

    tags = {
        Name = "ram_public_subnet1"
        created_by = "Terraform"
    }
}
resource "aws_subnet" "ram_public_subnet2" {
    vpc_id = "${aws_vpc.ram_vpc.id}"     # 0.11.7 
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = true 
    availability_zone = "ap-south-1b"

    tags = {
        Name = "ram_public_subnet2"
        created_by = "Terraform"
    }
}

resource "aws_subnet" "ram_private_subnet1" {
    vpc_id = "${aws_vpc.ram_vpc.id}"     # 0.11.7 
    cidr_block = "10.0.3.0/24"
    availability_zone = "ap-south-1a"

    tags = {
        Name = "ram_private_subnet1"
        created_by = "Terraform"
    }
}
resource "aws_subnet" "ram_private_subnet2" {
    vpc_id = "${aws_vpc.ram_vpc.id}"     # 0.11.7 
    cidr_block = "10.0.4.0/24"
    availability_zone = "ap-south-1b"

    tags = {
        Name = "ram_private_subnet2"
        created_by = "Terraform"
    }
}

# IGW
resource "aws_internet_gateway" "ram_igw" {
    vpc_id = "${aws_vpc.ram_vpc.id}"

    tags = {
        Name = "ram_igw"
        Created_By = "Terraform"
    }  
}

# RTB
resource "aws_route_table" "ram_rtb_public" {
    vpc_id = "${aws_vpc.ram_vpc.id}"

    tags = {
        Name = "ram_rtb_public"
        Created_By = "Terraform"
    }
}
resource "aws_route_table" "ram_rtb_private" {
    vpc_id = "${aws_vpc.ram_vpc.id}"

    tags = {
        Name = "ram_rtb_private"
        Created_By = "Terraform"
    }
}

# Create the internet Access 
resource "aws_route" "ram_rtb_igw" {
    route_table_id = "${aws_route_table.ram_rtb_public.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ram_igw.id}"

}

resource "aws_route_table_association" "ram_subnet_association1" {
    subnet_id = "${aws_subnet.ram_public_subnet1.id}"
    route_table_id = "${aws_route_table.ram_rtb_public.id}"
}
resource "aws_route_table_association" "ram_subnet_association2" {
    subnet_id = "${aws_subnet.ram_public_subnet2.id}"
    route_table_id = "${aws_route_table.ram_rtb_public.id}"
}
resource "aws_route_table_association" "ram_subnet_association3" {
    subnet_id = "${aws_subnet.ram_private_subnet1.id}"
    route_table_id = "${aws_route_table.ram_rtb_private.id}"
}
resource "aws_route_table_association" "ram_subnet_association4" {
    subnet_id = "${aws_subnet.ram_private_subnet2.id}"
    route_table_id = "${aws_route_table.ram_rtb_private.id}"
}

# Elastic Ipaddress for NAT Gateway
resource "aws_eip" "ram_eip" {
  vpc = true
}

# Create Nat Gateway 
resource "aws_nat_gateway" "ram_gw" {
    allocation_id = "${aws_eip.ram_eip.id}"
    subnet_id = "${aws_subnet.ram_public_subnet1.id}"

    tags = {
        Name = "Nat Gateway"
        Createdby = "Terraform"
    }
}


# Allow internet access from NAT Gateway to Private Route Table
resource "aws_route" "ram_rtb_private_gw" {
    route_table_id = "${aws_route_table.ram_rtb_private.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.ram_gw.id}"
}

# Network Access Control List 
resource "aws_network_acl" "ram_nsg" {
    vpc_id = "${aws_vpc.ram_vpc.id}"
    subnet_ids = [
    "${aws_subnet.ram_public_subnet1.id}",
    "${aws_subnet.ram_public_subnet2.id}",
    "${aws_subnet.ram_private_subnet1.id}",
    "${aws_subnet.ram_private_subnet2.id}"
    ]

    # All ingress port 22 
    ingress {
        protocol    = -1
        rule_no     = 100
        action      = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0 
        to_port     = 0 
    }

    # Allow egress of port 22
    egress {
        protocol = -1
        rule_no  = 100
        action   = "allow"
        cidr_block = "0.0.0.0/0"
        from_port = 0
        to_port   = 0 
    }

    tags = {
        Name = "ram_nsg"
        createdby = "Terraform"
    }
}

# EC2 instance Security group
resource "aws_security_group" "ram_sg_bastion" {
    vpc_id = "${aws_vpc.ram_vpc.id}"
    name   = "sg_ram_ssh_rdp"
    description = "To Allow SSH From IPV4 Devices"

    # Allow Ingress / inbound Of port 22 
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 22
        to_port     = 22 
        protocol    = "tcp"
    }
    # Allow Ingress / inbound Of port 8080 
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
    }
    # Allow egress / outbound of all ports 
    egress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ram_sg_bastion"
        Description = "ram allow SSH - RDP"
        createdby = "terraform"
    }

}

# EC2 instance Security group
resource "aws_security_group" "ram_sg" {
    vpc_id = "${aws_vpc.ram_vpc.id}"
    name   = "sg_ram_ssh"
    description = "To Allow SSH From IPV4 Devices"

    # Allow Ingress / inbound Of port 22 
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 22
        to_port     = 22 
        protocol    = "tcp"
    }
    # Allow Ingress / inbound Of port 80 
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 80
        to_port     = 80 
        protocol    = "tcp"
    }
    # Allow Ingress / inbound Of port 8080 
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
    }
    # Allow egress / outbound of all ports 
    egress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ram_sg"
        Description = "ram allow SSH - HTTP and Jenkins"
        createdby = "terraform"
    }

}

# Bastion - Windows 
resource "aws_instance" "ram_bastion" {
    ami = "ami-013f17f36f8b1fefb"
    instance_type = "t2.micro"
    key_name = "softodevops"
    subnet_id = "${aws_subnet.ram_public_subnet1.id}"
    vpc_security_group_ids = ["${aws_security_group.ram_sg_bastion.id}"]
    tags = {
        Name = "ram_Bastion"
        CreatedBy = "Terraform"
    }
}

data "aws_ami" "selected_app_ami" {
    most_recent = true 
    owners      = [var.ram_ami_account]
    
    filter {
        name = "name"

        values = [ 
            "softobiz-${var.ram-app_version}",
        ]
    }

    filter {
      name = "owner-id"
      values = ["${var.ram_ami_account}"]
    }

    filter {
      name = "root-device-type"
      values = ["ebs"]
    }

    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }

}
# WebServer - Private Subnet 
resource "aws_instance" "ram_web" {
    ami = "${data.aws_ami.selected_app_ami.id}"
    instance_type = "t2.micro"
    key_name = "softodevops"
    subnet_id = "${aws_subnet.ram_private_subnet1.id}"
    vpc_security_group_ids = ["${aws_security_group.ram_sg.id}"]
    #user_data = "${file("web.sh")}"
    tags = {
        Name = "ram_web"
        CreatedBy = "Terraform"
    }
}
