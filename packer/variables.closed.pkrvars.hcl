environment = "closed"
image_name = "rhel8-custom"
ssh_username = "cloud-user"
base_image_path = "/path/to/baseline/rhel8-baseline.qcow2"  # Replace with actual path
output_directory = "output-vm"
memory_size = 2048
disk_size = 20480
cpus = 2

# Artifactory configuration
artifactory_url = "https://artifactory.internal.example.com"  # Internal Artifactory URL
artifactory_user = "artifactory_user"  # Will be overridden by CI/CD variables
artifactory_pass = "artifactory_pass"  # Will be overridden by CI/CD variables
package_list = [
  "myrpm-1.2.3.rpm",
  "otherpkg-4.5.6.rpm",
  "acme-mycollection-1.0.0.tar.gz"
] 