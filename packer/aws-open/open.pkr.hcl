variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "source_ami" {
  type = string
  description = "Source AMI ID for RHEL 8"
}

variable "ami_name" {
  type    = string
  default = "rhel8-custom-ami"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
}

variable "vpc_id" {
  type    = string
  description = "VPC ID where the instance will be launched"
}

variable "subnet_id" {
  type    = string
  description = "Subnet ID where the instance will be launched"
}

source "amazon-ebs" "rhel8_base" {
  region           = var.aws_region
  source_ami       = var.source_ami
  instance_type    = var.instance_type
  ssh_username     = var.ssh_username
  ami_name         = "${var.ami_name}-${timestamp()}"
  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id

  ami_description = "Custom RHEL 8 AMI with additional packages and configurations"
  ami_users       = ["self"]  # Add other AWS account IDs as needed

  tags = {
    Name        = "${var.ami_name}-${timestamp()}"
    Environment = "open"
    Project     = "shipbuilder"
  }
}

build {
  sources = ["source.amazon-ebs.rhel8_base"]

  provisioner "ansible" {
    playbook_file  = "../../ansible/customize.yml"
    user           = var.ssh_username
    extra_arguments = [
      "-e", "ansible_python_interpreter=/usr/bin/python3",
      "-e", "environment=open"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
} 