environment = "open"
image_name = "rhel8-custom"
ssh_username = "ec2-user"
aws_region = "us-west-2"
source_ami = "ami-0c55b159cbfafe1f0"  # Example RHEL 8 AMI ID - replace with actual ID
instance_type = "t3.small"
vpc_id = "vpc-0123456789abcdef0"  # Replace with actual VPC ID
subnet_id = "subnet-0123456789abcdef0"  # Replace with actual Subnet ID

# Artifactory configuration
artifactory_url = "https://artifactory.example.com"
artifactory_user = "artifactory_user"  # Will be overridden by CI/CD variables
artifactory_pass = "artifactory_pass"  # Will be overridden by CI/CD variables
package_list = [
  "myrpm-1.2.3.rpm",
  "otherpkg-4.5.6.rpm",
  "acme-mycollection-1.0.0.tar.gz"
] 