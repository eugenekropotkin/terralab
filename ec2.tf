
variable "aws_region" {
  description = "AWS region"
  default     = "eu-central-1"
}


provider "aws" {
  access_key = "ACCESSKEY"
  secret_key = "PASSWORD"
  region = "${var.aws_region}"
}



data "aws_vpc" "selected" {
  id = "vpc-0fd96799c38660000"
}



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





resource "aws_instance" "terra" {
  # ami = "ami-090f10efc254eaf55"
  ami           = "${data.aws_ami.ubuntu.id}"

  instance_type = "t2.micro"

  tags {
    Name = "TerraForm"   # Name tag
  }

  key_name   = "sshKeyName"

  root_block_device {
    volume_size = "10"   # root device size, GB
  }

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = 8
    volume_type = "gp2"
    delete_on_termination = true
  }

  # if default VPC is deleted - must have
  subnet_id = "subnet-064e717da4a600000"
}

