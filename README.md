# Shipbuilder - RHEL 8 Image Build Automation

This project automates the creation of RHEL 8 images for both Open (AWS) and Closed (KVM/vSphere) environments. The process supports installing custom packages, internal RPMs, and Ansible collections from enterprise repositories.

## Project Structure

```
shipbuilder/
├── scripts/
│   └── build_baseline.sh           # Bash script for baseline image creation
├── packer/
│   ├── main.pkr.hcl               # Unified Packer template for both environments
│   ├── variables.open.pkrvars.hcl # Variables for AWS build
│   └── variables.closed.pkrvars.hcl # Variables for KVM/vSphere build
├── ansible/
│   └── customize.yml              # Ansible playbook for provisioning
├── blueprint.toml                 # Image Builder blueprint
└── .gitlab-ci.yml                 # GitLab CI pipeline configuration
```

## Environments

### Open Environment (AWS)
- Infrastructure: AWS (for building and hosting AMIs)
- CI/CD: GitLab with runners in AWS
- Security/Secrets: Vault
- Artifacts: Artifactory

### Closed Environment (KVM/vSphere)
- Infrastructure: On-prem KVM and vSphere
- CI/CD: GitLab with runners on-prem
- Security/Secrets: Vault (on-prem instance)
- Artifacts: Artifactory (mirrored/accessible in closed network)

## Build Process

1. **Baseline Image Creation**: Creates a base RHEL 8 image using Red Hat Image Builder's REST API
2. **Package Preparation**: Downloads required packages from Artifactory to the build environment
3. **Environment-Specific Build**:
   - Open: Builds AWS AMI using Packer
   - Closed: Creates KVM/vSphere images using Packer
4. **Image Customization**: Applies configurations using Ansible
5. **Post-Processing**: 
   - Open: Creates AMI in AWS
   - Closed: Converts to OVA format for vSphere

## Package Management

The project uses a unified approach for package management:

1. **Package List**: Defined in Packer variables (`package_list`)
2. **Pre-Download**: Packages are downloaded from Artifactory before Ansible runs
3. **Local Installation**: Ansible installs packages from local storage
4. **Environment Support**: 
   - Open: Uses public Artifactory instance
   - Closed: Uses internal Artifactory mirror

## Prerequisites

- Red Hat Image Builder access
- AWS credentials (for open environment)
- KVM/vSphere access (for closed environment)
- Vault for secrets management
- Artifactory access
- GitLab CI/CD pipeline configured

## Configuration

### Packer Configuration
- Single unified template (`main.pkr.hcl`)
- Environment-specific variables files
- Dynamic builder selection based on environment
- Common provisioning process
- Artifactory package pre-download configuration
- Environment-specific post-processors

### Ansible Configuration
- Unified playbook for both environments
- Environment-specific variables
- Local package installation
- System configuration
- SELinux and firewall rules
- System hardening tasks

### CI/CD Configuration
- Automated pipeline stages
- Secure credential management via Vault
- Environment-specific variables
- Manual approval for image transfer
- Artifact retention policies
- Pipeline dependencies

## Development Setup

1. Install required tools:
   ```bash
   # Clone the repository
   git clone https://gitlab.com/your-org/shipbuilder.git
   cd shipbuilder

   # Install pre-commit hooks
   pip install pre-commit
   pre-commit install

   # Initialize development environment
   make init
   ```

2. Configure local development:
   ```bash
   # Set up environment variables
   cp .env.example .env
   # Edit .env with your configuration

   # Authenticate with Vault and get Artifactory credentials
   make vault-auth VAULT_USERNAME=your-username VAULT_PASSWORD=your-password
   ```

3. Test locally:
   ```bash
   # Run tests
   make test

   # Build images
   make build-open    # For AWS environment
   make build-closed  # For KVM/vSphere environment

   # Run CI pipeline locally
   make ci
   ```

### Development Tools

The project includes several development tools to ensure code quality:

1. **Makefile**: Simplifies common operations
   - `make init`: Set up development environment
   - `make build-open`: Build AWS image
   - `make build-closed`: Build KVM/vSphere image
   - `make test`: Run tests
   - `make clean`: Clean build artifacts
   - `make validate`: Validate configurations
   - `make lint`: Run linters
   - `make ci`: Run CI pipeline locally
   - `make vault-auth`: Authenticate with Vault and get Artifactory credentials

2. **Pre-commit Hooks**: Ensures code quality before commits
   - YAML validation
   - Ansible linting
   - Shell script checking
   - Packer formatting
   - Python code formatting
   - Security checks

3. **Environment Variables**: 
   - `.env.example`: Template for required environment variables
   - `.env`: Local environment configuration (not committed)

4. **Git Ignore Rules**:
   - Excludes sensitive files
   - Ignores build artifacts
   - Prevents temporary files from being committed

## Troubleshooting

### Common Issues

1. **Package Download Failures**
   - Verify Artifactory credentials in Vault
   - Check network connectivity to Artifactory
   - Validate package names and versions
   - Check Artifactory repository permissions

2. **Build Failures**
   - Check Packer logs in `packer.log`
   - Verify AWS/KVM credentials
   - Check resource availability (memory, disk space)
   - Validate network connectivity

3. **Ansible Execution Issues**
   - Check Ansible logs
   - Verify Python interpreter path
   - Check package installation permissions
   - Validate SELinux contexts

4. **CI/CD Pipeline Issues**
   - Check GitLab CI/CD logs
   - Verify Vault connectivity
   - Check runner status and configuration
   - Validate artifact retention policies

### Debug Mode

Enable debug logging for more detailed information:

```bash
# Packer debug
export PACKER_LOG=1
export PACKER_LOG_PATH="packer.log"

# Ansible debug
ansible-playbook -vvv ansible/customize.yml

# GitLab Runner debug
gitlab-runner --debug run
```

## Monitoring and Maintenance

### Health Checks
- Pipeline execution status
- Build success rates
- Package download success rates
- Resource utilization
- Security compliance status

### Regular Maintenance
- Update base RHEL 8 image
- Rotate credentials
- Update package versions
- Review and update security policies
- Clean up old artifacts

### Backup and Recovery
- Regular backup of configuration files
- Document recovery procedures
- Maintain rollback procedures
- Test recovery processes

## Usage

1. Configure secrets in Vault:
   - Artifactory credentials
   - AWS credentials
   - vSphere credentials

2. Update environment variables:
   - Open: AWS region, VPC, subnet IDs
   - Closed: Base image path, VM specifications

3. Run the GitLab CI pipeline:
   ```bash
   gitlab-ci-multi-runner exec docker build_baseline
   gitlab-ci-multi-runner exec docker customize_open
   gitlab-ci-multi-runner exec docker customize_closed
   ```

4. Monitor build progress in GitLab

## Security Notes

- All sensitive credentials are managed through Vault
- Network separation between open and closed environments
- Secure transfer mechanisms for artifacts between environments
- Package verification and GPG key validation
- SELinux and firewall configurations
- Vault authentication using LDAP
- Secure token storage with appropriate permissions
- Environment variable management for sensitive data

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 