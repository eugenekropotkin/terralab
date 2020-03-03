#test project

provider "aws" {
  access_key = "VVVVVVVVVVV"
  secret_key = "PPPPPPPPPPP"
  region = "${var.aws_region}"
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

resource "aws_vpc" "default" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true

    tags = { Name = "vpc1" }
}

resource "aws_internet_gateway" "igw1" {
    vpc_id = "${aws_vpc.default.id}"
}



#data "aws_vpc" "main" {
#  id = "vpc-0fd96799c3866c19f"
#}



data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*18.04*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}




resource "aws_subnet" "public1" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "10.0.1.0/24"

  availability_zone = "eu-central-1a"

  tags = {
    Name = "public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "10.0.2.0/24"

  availability_zone = "eu-central-1b"

  tags = {
    Name = "public2"
  }
}


resource "aws_subnet" "private1" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "10.0.4.0/22"

  availability_zone = "eu-central-1a"

  tags = {
    Name = "prvate1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "10.0.8.0/22"

  availability_zone = "eu-central-1b"
  
  tags = {
    Name = "prvate2"
  }
}




resource "aws_network_acl" "public_nacl1" {
  vpc_id     = "${aws_vpc.default.id}"
  subnet_ids = formatlist( "%s", ["${aws_subnet.public1.id}", "${aws_subnet.public2.id}"] )


  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  tags = {
    Name = "pub-main"
  }

}






# bastion1 instance
resource "aws_instance" "bastion1" {
  # ami = "ami-090f10efc254eaf55"
  ami           = "${data.aws_ami.ubuntu.id}"

  instance_type = "t2.nano"

  tags = {
    Name = "bastion1"
  }

  key_name   = "kf2019"

  associate_public_ip_address = "true"

  #security_groups = [
  #      "sg-015aaf83c97770aa3"
  #]

  root_block_device {
    volume_size = "15"   # root device size, GB
  }

#  ebs_block_device {
#    device_name = "/dev/xvdb"
#    volume_size = 8
#    volume_type = "gp2"
#    delete_on_termination = true
#  }

  private_ip = "10.0.1.11"

  # if default VPC is deleted - must have
  subnet_id = "${aws_subnet.public1.id}"
}



	

resource "aws_instance" "bastion2" {
  # ami = "ami-090f10efc254eaf55"
  ami           = "${data.aws_ami.ubuntu.id}"

  instance_type = "t2.nano"

  tags = {
    Name = "bastion2"
  }

  key_name   = "kf2019"

  associate_public_ip_address = "true"

  #security_groups = [
  #      "sg-015aaf83c97770aa3"
  #]

  root_block_device {
    volume_size = "15"   # root device size, GB
  }

#  ebs_block_device {
#    device_name = "/dev/xvdb"
#    volume_size = 8
#    volume_type = "gp2"
#    delete_on_termination = true
#  }

  private_ip = "10.0.2.11"

  # if default VPC is deleted - must have
  subnet_id = "${aws_subnet.public2.id}"
}







