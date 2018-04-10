variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "ssh_public_key" {}

provider "aws" {
  region = "us-east-1"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

resource "aws_vpc" "cbo_vpc" {
  cidr_block = "172.16.0.0/16"
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

resource "aws_subnet" "cbo_subnet" {
  vpc_id = "${aws_vpc.cbo_vpc.id}"
  cidr_block = "172.16.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "cbo_sec_default" {
  name = "cbo_default"
  description = "Kubernetes enabled security group"
  vpc_id = "${aws_vpc.cbo_vpc.id}"

  # SSH access for provisioning and debug
  ingress {
    from_port = 0
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8S access for testing via the API
  ingress {
    from_port = 0
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker access for building images
  ingress {
    from_port = 0
    to_port = 2376
    protocol = "tcp"
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

resource "aws_instance" "cbo_kubernetes0" {
  connection {
    user = "ubuntu"
  }
  instance_type = "m4.large" # 2 vCPU, 8 GiB, EBS optimized, Moderate network
  ami = "ami-43a15f3e" # Ubuntu 16.04
  key_name = "${aws_key_pair.cbo_keypair.id}"
  vpc_security_group_ids = ["${aws_security_group.cbo_sec_default.id}"]
  subnet_id = "${aws_subnet.cbo_subnet.id}"

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
      "wget -q https://raw.githubusercontent.com/spjmurray/couchbase-operator-ci/master/puppet/manifests/site.pp",
      "sudo /opt/puppetlabs/bin/puppet apply site.pp",
    ]
  }
}

output "kubernetes0" {
  value = "${aws_instance.cbo_kubernetes0.public_dns}"
}
