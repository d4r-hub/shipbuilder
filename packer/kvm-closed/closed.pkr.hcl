variable "base_image_path" {
  type    = string
  description = "Path to the baseline QCOW2 image"
}

variable "output_image_name" {
  type    = string
  default = "rhel8-closed-custom"
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

source "qemu" "rhel8_closed" {
  accelerator      = "kvm"
  disk_image       = var.base_image_path
  output_directory = var.output_directory
  output_format    = "qcow2"
  vm_name          = var.output_image_name
  headless         = true
  memory           = var.memory_size
  disk_size        = var.disk_size
  cpus             = var.cpus
  shutdown_command = "sudo shutdown -P now"
  ssh_username     = "cloud-user"
  ssh_wait_timeout = "20m"
}

build {
  sources = ["source.qemu.rhel8_closed"]

  provisioner "ansible" {
    playbook_file = "../../ansible/customize.yml"
    user          = "cloud-user"
    extra_arguments = [
      "-e", "ansible_python_interpreter=/usr/bin/python3",
      "-e", "environment=closed"
    ]
  }

  post-processor "vsphere-ova" {
    output_directory = "output-ova"
    keep_input_artifact = false
    vm_name    = var.output_image_name
    format     = "ova"
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
} 