variable "environment" {
  type    = string
  description = "Target environment (open or closed)"
  validation {
    condition     = contains(["open", "closed"], var.environment)
    error_message = "Environment must be either 'open' or 'closed'."
  }
}

# Common variables for both environments
variable "image_name" {
  type    = string
  default = "rhel8-custom"
}

variable "ssh_username" {
  type    = string
  default = "ec2-user"
}

# Artifactory variables
variable "artifactory_url" {
  type    = string
  description = "Artifactory URL for package downloads"
}

variable "artifactory_user" {
  type    = string
  description = "Artifactory username"
}

variable "artifactory_pass" {
  type    = string
  description = "Artifactory password"
}

variable "package_list" {
  type    = list(string)
  default = [
    "myrpm-1.2.3.rpm",
    "otherpkg-4.5.6.rpm",
    "acme-mycollection-1.0.0.tar.gz"
  ]
}

# AWS-specific variables
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "source_ami" {
  type    = string
  description = "Source AMI ID for RHEL 8"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "vpc_id" {
  type    = string
  description = "VPC ID where the instance will be launched"
}

variable "subnet_id" {
  type    = string
  description = "Subnet ID where the instance will be launched"
}

# KVM/vSphere-specific variables
variable "base_image_path" {
  type    = string
  description = "Path to the baseline QCOW2 image"
}

variable "output_directory" {
  type    = string
  default = "output-vm"
}

variable "memory_size" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type    = number
  default = 20480
}

variable "cpus" {
  type    = number
  default = 2
}

# AWS builder
source "amazon-ebs" "rhel8_base" {
  region           = var.aws_region
  source_ami       = var.source_ami
  instance_type    = var.instance_type
  ssh_username     = var.ssh_username
  ami_name         = "${var.image_name}-${var.environment}-${timestamp()}"
  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id

  ami_description = "Custom RHEL 8 AMI with additional packages and configurations"
  ami_users       = ["self"]  # Add other AWS account IDs as needed

  tags = {
    Name        = "${var.image_name}-${var.environment}-${timestamp()}"
    Environment = var.environment
    Project     = "shipbuilder"
  }
}

# KVM builder
source "qemu" "rhel8_closed" {
  accelerator      = "kvm"
  disk_image       = var.base_image_path
  output_directory = var.output_directory
  output_format    = "qcow2"
  vm_name          = "${var.image_name}-${var.environment}"
  headless         = true
  memory           = var.memory_size
  disk_size        = var.disk_size
  cpus             = var.cpus
  shutdown_command = "sudo shutdown -P now"
  ssh_username     = var.ssh_username
  ssh_wait_timeout = "20m"
}

# Common build configuration
build {
  sources = [
    var.environment == "open" ? "source.amazon-ebs.rhel8_base" : "source.qemu.rhel8_closed"
  ]

  # Shell provisioner to download packages from Artifactory
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/packages",
      "cd /tmp/packages",
      "for pkg in ${join(" ", var.package_list)}; do",
      "  curl -s -u ${var.artifactory_user}:${var.artifactory_pass} \\",
      "    -O ${var.artifactory_url}/repos/packages/$pkg",
      "done"
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }}sudo -E -S sh '{{ .Path }}'"
  }

  provisioner "ansible" {
    playbook_file  = "../ansible/customize.yml"
    user           = var.ssh_username
    extra_arguments = [
      "-e", "ansible_python_interpreter=/usr/bin/python3",
      "-e", "environment=${var.environment}",
      "-e", "artifactory_url=${var.artifactory_url}",
      "-e", "artifactory_user=${var.artifactory_user}",
      "-e", "artifactory_pass=${var.artifactory_pass}"
    ]
  }

  # Post-processors based on environment
  dynamic "post-processor" {
    for_each = var.environment == "closed" ? [1] : []
    content {
      type = "vsphere-ova"
      output_directory = "output-ova"
      keep_input_artifact = false
      vm_name    = "${var.image_name}-${var.environment}"
      format     = "ova"
    }
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
} 