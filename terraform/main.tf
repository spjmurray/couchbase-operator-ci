# Secret or dynamic input variables
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "ssh_public_key" {}
variable "region" {}

# Local configuration
locals {
  # Our overlays will live in the 10.0.0.0/8 space
  supernet_prefix = "172.16.0.0/16"
  # Each AZ needs a subnet prefix
  num_availability_zones = 3
  subnet_prefixes = [
    "172.16.0.0/24",
    "172.16.1.0/24",
    "172.16.2.0/24",
  ]
  # Number of K8S slaves to provision
  num_slaves = 3
}

provider "aws" {
  region = "${var.region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

resource "aws_vpc" "cbo_vpc" {
  cidr_block = "${local.supernet_prefix}"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "cbo_gateway" {
  vpc_id = "${aws_vpc.cbo_vpc.id}"
}

resource "aws_route" "cbo_default_route" {
  route_table_id = "${aws_vpc.cbo_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.cbo_gateway.id}"
}

data "aws_availability_zones" "availability_zones" {}

resource "aws_subnet" "cbo_subnet" {
  count = "${local.num_availability_zones}"
  vpc_id = "${aws_vpc.cbo_vpc.id}"
  cidr_block = "${element(local.subnet_prefixes, count.index)}"
  availability_zone = "${element(data.aws_availability_zones.availability_zones.names, count.index)}"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "cbo_sec_default" {
  name = "cbo_default"
  description = "Kubernetes enabled security group"
  vpc_id = "${aws_vpc.cbo_vpc.id}"

  ingress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "cbo_keypair" {
  key_name = "couchbase-operator"
  public_key = "${file(var.ssh_public_key)}"
}

data "aws_ami" "ubuntu_xenial" {
  most_recent = true
  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*",
    ]
  }
  filter {
    name = "virtualization-type"
    values = [
      "hvm",
    ]
  }
  owners = [
    "099720109477"
  ]
}

resource "aws_instance" "cbo_kubernetes_master" {
  connection {
    user = "ubuntu"
  }
  instance_type = "m4.large"
  ami = "${data.aws_ami.ubuntu_xenial.id}"
  key_name = "${aws_key_pair.cbo_keypair.id}"
  vpc_security_group_ids = [
    "${aws_security_group.cbo_sec_default.id}",
  ]

  # Install the master in the first subnet
  subnet_id = "${aws_subnet.cbo_subnet.0.id}"

  # Copy over certificates to be used extenally
  provisioner "file" {
    source = "tls/server"
    destination = "/home/ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv server /etc/docker",
    ]
  }

  # Provision the kubernetes cluster with puppet
  provisioner "remote-exec" {
    inline = [
      "wget -q https://apt.puppet.com/puppetlabs-release-pc1-xenial.deb",
      "sudo dpkg -i puppetlabs-release-pc1-xenial.deb",
      "sudo apt-get update",
      "sudo apt-get -y install puppet-agent",
      "sudo /opt/puppetlabs/bin/puppet module install spjmurray/kubernetes",
      "sudo /opt/puppetlabs/bin/puppet apply -e 'include ::kubernetes'",
    ]
  }
}

resource "aws_instance" "cbo_kubernetes_slave" {
  count = "${local.num_slaves}"
  connection {
    user = "ubuntu"
  }
  instance_type = "m4.large"
  ami = "${data.aws_ami.ubuntu_xenial.id}"
  key_name = "${aws_key_pair.cbo_keypair.id}"
  vpc_security_group_ids = [
    "${aws_security_group.cbo_sec_default.id}"
  ]

  # Distribute slaves over all availability zones
  subnet_id = "${element(aws_subnet.cbo_subnet.*.id, count.index)}"

  # Copy over certificates to be used extenally
  provisioner "file" {
    source = "tls/server"
    destination = "/home/ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv server /etc/docker",
    ]
  }

  # Provision the kubernetes cluster with puppet
  provisioner "remote-exec" {
    inline = [
      "wget -q https://apt.puppet.com/puppetlabs-release-pc1-xenial.deb",
      "sudo dpkg -i puppetlabs-release-pc1-xenial.deb",
      "sudo apt-get update",
      "sudo apt-get -y install puppet-agent",
      "sudo /opt/puppetlabs/bin/puppet module install spjmurray/kubernetes",
      "sudo /opt/puppetlabs/bin/puppet apply -e \"class { 'kubernetes': type => 'slave', master => '${aws_instance.cbo_kubernetes_master.private_ip}' }\"",
    ]
  }
}


output "kubernetes_master" {
  value = "${aws_instance.cbo_kubernetes_master.public_dns}"
}

output "kubernetes_slave" {
  value = "${aws_instance.cbo_kubernetes_slave.*.public_dns}"
}
