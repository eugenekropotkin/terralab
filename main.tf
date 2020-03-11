# test terraform project
#
# deploys 2 public networks + 2 bastion hosts + IGW + NAT
# deploys 2 private networks + 2 test hosts
# + ACL between network areas


variable "aws_region" {
  default = "eu-central-1"
  #default = "us-east-1"
}


# defined in creds.tf
provider "aws" {
  access_key = var.aws_ak1
  secret_key = var.aws_sk1
  region = var.aws_region
}

variable "aws_key" {
  default = "keaws2020"
}


#### networking variables

variable "vpc1_cidr" {
  description = "CIDR for the VPC"
  default = "10.0.0.0/16"
}

variable "subnetpub1" {
  type = map
  default = {
    name = "public1",
    cidr = "10.0.1.0/24",
    az = "a"
  }
}

variable "subnetpub2" {
  type = map
  default = {
    name = "public2",
    cidr = "10.0.2.0/24",
    az = "b"
  }
}

variable "subnetpriv1" {
  type = map
  default = {
    name = "private1",
    cidr = "10.0.4.0/22",
    az = "a"
  }
}

variable "subnetpriv2" {
  type = map
  default = {
    name = "private2",
    cidr = "10.0.8.0/22",
    az = "b"
  }
}


#### networking create

resource "aws_vpc" "default" {
  cidr_block = var.vpc1_cidr
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "vpc1"
  }
}


##### nat, private subnets ####

resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.default.id
}

# assign eip to igw1
resource "aws_eip" "igw1ip" {
  vpc = true
  depends_on = [
    aws_internet_gateway.igw1]
}


## NAT gateway
resource "aws_nat_gateway" "ngw1" {
  allocation_id = aws_eip.igw1ip.id
  subnet_id = aws_subnet.public1.id
  depends_on = [
    aws_internet_gateway.igw1,
    aws_subnet.private1,
    aws_subnet.private2]
}


## Default route to Internet

resource "aws_route" "internet_access" {
  route_table_id = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw1.id
  depends_on = [
    aws_internet_gateway.igw1]
}

## Routing table

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "Private route table"
  }

}

resource "aws_route" "private_route" {
  route_table_id = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.ngw1.id

  depends_on = [
    aws_nat_gateway.ngw1]
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }
  depends_on = [
    aws_internet_gateway.igw1]

  tags = {
    Name = "Public route table"
  }
}


## Route tables associations

# Associate subnet public_subnet to public route table
resource "aws_route_table_association" "public_subnet_association1" {
  subnet_id = aws_subnet.public1.id
  route_table_id = aws_vpc.default.main_route_table_id
  depends_on = [
    aws_internet_gateway.igw1]
}
resource "aws_route_table_association" "public_subnet_association2" {
  subnet_id = aws_subnet.public2.id
  route_table_id = aws_vpc.default.main_route_table_id
  depends_on = [
    aws_internet_gateway.igw1]
}

# Associate subnet private_subnet to private route table
resource "aws_route_table_association" "private_subnet_association1" {
  subnet_id = aws_subnet.private1.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private_subnet_association2" {
  subnet_id = aws_subnet.private2.id
  route_table_id = aws_route_table.private_route_table.id
}


## networks

# public1
resource "aws_subnet" "public1" {
  vpc_id = aws_vpc.default.id
  cidr_block = var.subnetpub1["cidr"]
  availability_zone = format("%s%s", var.aws_region, var.subnetpub1["az"])
  tags = {
    Name = var.subnetpub1["name"]
  }
}

# public2
resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.default.id
  cidr_block = var.subnetpub2["cidr"]
  availability_zone = format("%s%s", var.aws_region, var.subnetpub2["az"])
  tags = {
    Name = var.subnetpub2["name"]
  }
}

# private1
resource "aws_subnet" "private1" {
  vpc_id = aws_vpc.default.id
  cidr_block = var.subnetpriv1["cidr"]
  availability_zone = format("%s%s", var.aws_region, var.subnetpriv1["az"])
  tags = {
    Name = var.subnetpriv1["name"]
  }
}

# private2
resource "aws_subnet" "private2" {
  vpc_id = aws_vpc.default.id
  cidr_block = var.subnetpriv2["cidr"]
  availability_zone = format("%s%s", var.aws_region, var.subnetpriv2["az"])
  tags = {
    Name = var.subnetpriv2["name"]
  }
}


#### NACL

resource "aws_network_acl" "public_nacl1" {
  vpc_id = aws_vpc.default.id
  subnet_ids = formatlist( "%s", [
    aws_subnet.public1.id,
    aws_subnet.public2.id] )


  egress {
    from_port = 0
    to_port = 0
    rule_no = 200
    action = "allow"
    protocol = "-1"
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    protocol = "tcp"
    rule_no = 201
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 22
    to_port = 22
  }

  egress {
    protocol = -1
    rule_no = 202
    action = "allow"
    cidr_block = var.vpc1_cidr
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = -1
    rule_no = 203
    action = "allow"
    cidr_block = var.vpc1_cidr
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "pub-main"
  }

}


resource "aws_network_acl" "priv_nacl1" {
  vpc_id = aws_vpc.default.id
  subnet_ids = formatlist( "%s", [
    aws_subnet.private1.id,
    aws_subnet.private2.id] )


  egress {
    protocol = -1
    rule_no = 300
    action = "allow"
    cidr_block = var.vpc1_cidr
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = -1
    rule_no = 301
    action = "allow"
    cidr_block = var.vpc1_cidr
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "priv-main"
  }

}


#### SG

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.default.id
}


resource "aws_security_group" "sg_bastion" {
  name = "sg_bastion"
  description = "ACL rules for Bastion hosts"
  vpc_id = aws_vpc.default.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      var.vpc1_cidr]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

}

resource "aws_security_group" "sg_ssh" {
  name = "sg_ssh"
  description = "ACL rules for ssh access to hosts"
  vpc_id = aws_vpc.default.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      var.vpc1_cidr]
  }

  egress {
    from_port = 1024
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = [
      var.vpc1_cidr]
  }

}


# attach SG to bastion hosts

resource "aws_network_interface_sg_attachment" "sg_attachment1" {
  security_group_id = aws_security_group.sg_bastion.id
  network_interface_id = aws_instance.bastion1.primary_network_interface_id
  depends_on = [
    aws_internet_gateway.igw1,
    aws_instance.bastion1]
}


resource "aws_network_interface_sg_attachment" "sg_attachment2" {
  security_group_id = aws_security_group.sg_bastion.id
  network_interface_id = aws_instance.bastion2.primary_network_interface_id
  depends_on = [
    aws_internet_gateway.igw1,
    aws_instance.bastion2]
}

/**/


#### AMI


# AMI dictionary
#    borrowed here: https://github.com/otassetti/terraform-aws-ami-search/blob/master/variables.tf

# !warning: it's old, need to check!
# - checked: debian-10, ubuntu-18.04
#
variable "amis_os_map_regex" {
  description = "Map of regex to search amis"
  type = map

  default = {
    "ubuntu" = "^ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-.*",
    "ubuntu-14.04" = "^ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-.*",
    "ubuntu-16.04" = "^ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-.*",
    "ubuntu-18.04s" = "^ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-.*",
    "ubuntu-18.04" = "ubuntu/images/hvm-ssd/ubuntu*18.04*",
    "ubuntu-18.10" = "*ubuntu/images/hvm-ssd/ubuntu*18.10*server*",
    "ubuntu-19.04" = "^ubuntu/images/hvm-ssd/ubuntu-disco-19.04-amd64-server-.*",
    "centos" = "^CentOS.Linux.7.*x86_64.*",
    "centos-6" = "^CentOS.Linux.6.*x86_64.*",
    "centos-7" = "^CentOS.Linux.7.*x86_64.*",
    "centos-8" = "^CentOS.Linux.8.*x86_64.*",
    "rhel" = "^RHEL-7.*x86_64.*",
    "rhel-6" = "^RHEL-6.*x86_64.*",
    "rhel-7" = "^RHEL-7.*x86_64.*",
    "rhel-8" = "^RHEL-8.*x86_64.*",
    "debian" = "^debian-stretch-.*",
    "debian-8" = "^debian-jessie-.*",
    "debian-9" = "^debian-stretch-.*",
    "debian-10" = "debian*10*",
    "fedora-27" = "^Fedora-Cloud-Base-27-.*-gp2.*",
    "amazon" = "^amzn-ami-hvm-.*x86_64-gp2",
    "amazon-2_lts" = "^amzn2-ami-hvm-.*x86_64-gp2",
    "suse-les" = "^suse-sles-12-sp\\d-v\\d{8}-hvm-ssd-x86_64",
    "suse-les-12" = "^suse-sles-12-sp\\d-v\\d{8}-hvm-ssd-x86_64",
    "windows" = "^Windows_Server-2019-English-Full-Base-.*",
    "windows-2019-base" = "^Windows_Server-2019-English-Full-Base-.*",
    "windows-2016-base" = "^Windows_Server-2016-English-Full-Base-.*",
    "windows-2012-r2-base" = "^Windows_Server-2012-R2_RTM-English-64Bit-Base-.*",
    "windows-2012-base" = "^Windows_Server-2012-RTM-English-64Bit-Base-.*",
    "windows-2008-r2-base" = "^Windows_Server-2008-R2_SP1-English-64Bit-Base-.*"
  }
}

variable "amis_os_map_owners" {
  description = "Map of amis owner to filter only official amis"
  type = map
  default = {
    "ubuntu" = "099720109477",
    #CANONICAL
    "ubuntu-14.04" = "099720109477",
    #CANONICAL
    "ubuntu-16.04" = "099720109477",
    #CANONICAL
    "ubuntu-18.04s" = "099720109477",
    #CANONICAL
    "ubuntu-18.04" = "099720109477",
    #CANONICAL
    "ubuntu-18.10" = "099720109477",
    #CANONICAL
    "ubuntu-19.04" = "099720109477",
    #CANONICAL
    "rhel" = "309956199498",
    #Amazon Web Services
    "rhel-6" = "309956199498",
    #Amazon Web Services
    "rhel-7" = "309956199498",
    #Amazon Web Services
    "rhel-8" = "309956199498",
    #Amazon Web Services
    "centos" = "679593333241",
    "centos-6" = "679593333241",
    "centos-7" = "679593333241",
    "centos-8" = "679593333241",
    "debian" = "679593333241",
    "debian-8" = "679593333241",
    "debian-9" = "679593333241",
    "debian-10" = "679593333241",
    "fedora-27" = "125523088429",
    #Fedora
    "amazon" = "137112412989",
    #amazon
    "amazon-2_lts" = "137112412989",
    #amazon
    "suse-les" = "013907871322",
    #amazon
    "suse-les-12" = "013907871322",
    #amazon
    "windows" = "801119661308",
    #amazon
    "windows-2019-base" = "801119661308",
    #amazon
    "windows-2016-base" = "801119661308",
    #amazon
    "windows-2012-r2-base" = "801119661308",
    #amazon
    "windows-2012-base" = "801119661308",
    #amazon
    "windows-2008-r2-base" = "801119661308"
    #amazon
  }
}


# look for Ubuntu 18.04
data "aws_ami" "image_bast" {
  most_recent = true

  filter {
    name = "name"
    values = formatlist( "%s", var.amis_os_map_regex["ubuntu-18.04"])
  }

  filter {
    name = "virtualization-type"
    values = [
      "hvm"]
  }

  owners = formatlist( "%s", [
    var.amis_os_map_owners["ubuntu-18.04"]])
}


# look for Debian 10
data "aws_ami" "image_deb10" {
  most_recent = true

  filter {
    name = "name"
    values = formatlist( "%s", var.amis_os_map_regex["debian-10"])
  }

  filter {
    name = "virtualization-type"
    values = [
      "hvm"]
  }

  owners = formatlist( "%s", [
    var.amis_os_map_owners["debian-10"]])
}


# bastion1 instance
resource "aws_instance" "bastion1" {
  ami = data.aws_ami.image_bast.id

  instance_type = "t2.nano"

  tags = {
    Name = "bastion1"
  }

  key_name = var.aws_key

  associate_public_ip_address = "true"

  security_groups = []

  root_block_device {
    volume_size = "15"
    # root device size, GB
  }

  private_ip = "10.0.1.4"
  subnet_id = aws_subnet.public1.id
}

output "bastion1out" {
  value = formatlist( "#inv bastions pub=%s priv=%s key=%s name=%s", aws_instance.bastion1.public_ip, aws_instance.bastion1.private_ip, aws_instance.bastion1.key_name, aws_instance.bastion1.tags["Name"])
  depends_on = [
    aws_instance.bastion1]
}


# bastion2 instance
resource "aws_instance" "bastion2" {
  ami = data.aws_ami.image_bast.id

  instance_type = "t2.nano"

  tags = {
    Name = "bastion2"
  }

  key_name = var.aws_key

  associate_public_ip_address = "true"

  security_groups = []

  root_block_device {
    volume_size = "15"
    # root device size, GB
  }

  private_ip = "10.0.2.4"
  subnet_id = aws_subnet.public2.id
}

output "bastion2out" {
  value = formatlist( "#inv bastions pub=%s priv=%s key=%s name=%s", aws_instance.bastion2.public_ip, aws_instance.bastion2.private_ip, aws_instance.bastion2.key_name, aws_instance.bastion2.tags["Name"])
  depends_on = [
    aws_instance.bastion1]
}


/* 
# search for image
data "aws_ami" "debian" {
  most_recent = true

  filter { 
    name   = "name"
    values = ["debian*10*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}
 
output "id_debian10" {
  value = data.aws_ami.debian.id
}
*/


variable "server1_count" {
  default = "1"
}

resource "aws_instance" "server1" {
  ami = data.aws_ami.image_deb10.id
  #ami = data.aws_ami.image_bast.id
  instance_type = "t2.nano"
  key_name = var.aws_key
  monitoring = false

  count = var.server1_count
  tags = {
    Name = format("server1-%d", count.index)
  }

  #private_ip = "10.0.4.4"
  subnet_id = aws_subnet.private1.id
  security_groups = [
    aws_security_group.sg_ssh.id]

  root_block_device {
    volume_size = "15"
    # root device size, GB
  }

  depends_on = [
    aws_nat_gateway.ngw1,
    aws_security_group.sg_ssh]
}

output "serv1out" {
  value = [
  for instance in aws_instance.server1:
  formatlist( "#inv servers pub=%s priv=%s key=%s name=%s", instance.public_ip, instance.private_ip, instance.key_name, instance.tags["Name"])
  ]
}


resource "aws_instance" "server2" {
  ami = data.aws_ami.image_deb10.id
  #ami = data.aws_ami.image_bast.id
  instance_type = "t2.nano"
  key_name = var.aws_key
  monitoring = false

  count = var.server1_count
  tags = {
    Name = format("server2-%d", count.index)
  }

  #private_ip = "10.0.4.4"
  subnet_id = aws_subnet.private2.id
  security_groups = [
    aws_security_group.sg_ssh.id]

  root_block_device {
    volume_size = "15"
    # root device size, GB
  }

  depends_on = [
    aws_nat_gateway.ngw1,
    aws_security_group.sg_ssh]
}

output "serv2out" {
  value = [
  for instance in aws_instance.server2:
  formatlist( "#inv servers pub=%s priv=%s key=%s name=%s", instance.public_ip, instance.private_ip, instance.key_name, instance.tags["Name"])
  ]
}

