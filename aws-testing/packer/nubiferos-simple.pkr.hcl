# Simple Packer template for NubiferOS AMI
# This is a minimal working example to get started quickly

packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "ami_name_prefix" {
  type    = string
  default = "nubiferos"
}

# Source: Start with Debian 12 base
source "amazon-ebs" "nubiferos" {
  region        = var.aws_region
  instance_type = var.instance_type
  
  # Use official Debian 12 AMI
  source_ami_filter {
    filters = {
      name                = "debian-12-amd64-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["136693071363"] # Debian official AWS account
  }
  
  # SSH configuration
  ssh_username = "admin"
  ssh_timeout  = "10m"
  
  # AMI configuration
  ami_name        = "${var.ami_name_prefix}-{{timestamp}}"
  ami_description = "NubiferOS - Multi-cloud management Linux distribution"
  
  # EBS volume configuration
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 20
    volume_type = "gp3"
    delete_on_termination = true
  }
  
  # Tags
  tags = {
    Name        = "NubiferOS"
    Version     = "1.0"
    Codename    = "Nimbus"
    Base        = "Debian 12"
    BuildDate   = "{{timestamp}}"
    Purpose     = "Testing"
    ManagedBy   = "Packer"
  }
  
  # Snapshot tags
  snapshot_tags = {
    Name      = "NubiferOS-Snapshot"
    BuildDate = "{{timestamp}}"
  }
}

# Build: Install and configure NubiferOS
build {
  sources = ["source.amazon-ebs.nubiferos"]
  
  # Update system
  provisioner "shell" {
    inline = [
      "echo '=== Updating system ==='",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
    ]
  }
  
  # Install GNOME desktop
  provisioner "shell" {
    inline = [
      "echo '=== Installing GNOME desktop ==='",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-core gdm3",
      "sudo systemctl set-default graphical.target",
    ]
  }
  
  # Install cloud tools
  provisioner "shell" {
    inline = [
      "echo '=== Installing cloud tools ==='",
      
      # AWS CLI
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "rm -rf aws awscliv2.zip",
      
      # Azure CLI
      "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash",
      
      # Google Cloud SDK
      "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list",
      "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -",
      "sudo apt-get update",
      "sudo apt-get install -y google-cloud-sdk",
      
      # Terraform
      "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt-get update",
      "sudo apt-get install -y terraform",
      
      # Docker
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sudo sh get-docker.sh",
      "sudo usermod -aG docker admin",
      "rm get-docker.sh",
      
      # kubectl
      "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl'",
      "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "rm kubectl",
    ]
  }
  
  # Install development tools
  provisioner "shell" {
    inline = [
      "echo '=== Installing development tools ==='",
      "sudo apt-get install -y git vim curl wget unzip jq python3 python3-pip",
    ]
  }
  
  # Install security tools
  provisioner "shell" {
    inline = [
      "echo '=== Configuring security ==='",
      "sudo apt-get install -y ufw fail2ban apparmor apparmor-utils",
      
      # Enable firewall
      "sudo ufw --force enable",
      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      
      # Enable AppArmor
      "sudo systemctl enable apparmor",
      "sudo systemctl start apparmor",
    ]
  }
  
  # Install credential management (pass)
  provisioner "shell" {
    inline = [
      "echo '=== Installing credential management ==='",
      "sudo apt-get install -y pass gnupg2",
    ]
  }
  
  # Configure cloud-init for AWS
  provisioner "shell" {
    inline = [
      "echo '=== Configuring cloud-init ==='",
      "sudo apt-get install -y cloud-init",
      "sudo systemctl enable cloud-init",
    ]
  }
  
  # Cleanup
  provisioner "shell" {
    inline = [
      "echo '=== Cleaning up ==='",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      
      # Clear bash history
      "cat /dev/null > ~/.bash_history",
      "history -c",
    ]
  }
  
  # Final message
  provisioner "shell" {
    inline = [
      "echo '=== NubiferOS AMI build complete! ==='",
      "echo 'Installed tools:'",
      "aws --version",
      "az version",
      "gcloud version",
      "terraform version",
      "docker --version",
      "kubectl version --client",
    ]
  }
}
