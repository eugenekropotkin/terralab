
variable "aws_region" {
  description = "AWS region"
  default     = "eu-central-1"
}


provider "aws" {
  access_key = "VVVVVVVVVVV"
  secret_key = "PPPPPPPPPPP"
  region = "${var.aws_region}"
}



data "aws_vpc" "selected" {
  id = "vpc-0fd96799c3866c19f"
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

  instance_type = "t2.nano"

  key_name   = "kf2019"
  associate_public_ip_address = "true"

  security_groups = [
        "sg-015aaf83c97770aa3"
  ]

  root_block_device {
    volume_size = "10"   # root device size, GB
  }

#  ebs_block_device {
#    device_name = "/dev/xvdb"
#    volume_size = 8
#    volume_type = "gp2"
#    delete_on_termination = true
#  }

  private_ip = "10.0.0.11"
  # if default VPC is deleted - must have
  subnet_id = "subnet-064e717da4a602809"
}


