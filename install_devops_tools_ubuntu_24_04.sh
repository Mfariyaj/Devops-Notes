#!/bin/bash
set -e

echo "=============================="
echo " DevOps Toolchain Installation"
echo " Ubuntu 24.04"
echo "=============================="

################################
# System Update
################################
sudo apt update -y
sudo apt install -y \
  curl \
  wget \
  unzip \
  tar \
  git \
  ca-certificates \
  gnupg \
  lsb-release

################################
# Jenkins (Snap)
################################
echo "Installing Jenkins (Snap)..."

if ! command -v snap &> /dev/null; then
  sudo apt install -y snapd
fi

sudo snap install jenkins --classic
sudo snap start jenkins

echo "Waiting for Jenkins to initialize..."
sleep 60

JENKINS_REV=$(ls /var/snap/jenkins | grep -E '^[0-9]+$' | sort -n | tail -1)

echo "Jenkins Initial Admin Password:"
sudo cat /var/snap/jenkins/$JENKINS_REV/secrets/initialAdminPassword

################################
# Docker
################################
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sudo bash
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

docker --version

################################
# AWS CLI v2
################################
echo "Installing AWS CLI v2..."
curl -o awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -o awscliv2.zip
sudo ./aws/install --update
aws --version

################################
# kubectl
################################
echo "Installing kubectl..."
curl -LO https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

################################
# eksctl
################################
echo "Installing eksctl..."
curl -sL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz -o eksctl.tar.gz
tar -xzf eksctl.tar.gz
sudo mv eksctl /usr/local/bin/
sudo chmod +x /usr/local/bin/eksctl
eksctl version

################################
# Terraform
################################
echo "Installing Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg \
| sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update -y
sudo apt install -y terraform
terraform -version

################################
# Trivy
################################
echo "Installing Trivy..."
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
| sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/trivy.list

sudo apt update -y
sudo apt install -y trivy
trivy --version

################################
# SonarQube (Docker)
################################
echo "Starting SonarQube (Docker)..."
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:lts

################################
# Summary
################################
echo "=============================="
echo " Installation Completed"
echo "=============================="
echo " Jenkins   : http://<SERVER-IP>:8080"
echo " SonarQube : http://<SERVER-IP>:9000 (admin/admin)"
echo ""
echo " IMPORTANT:"
echo " 1. Logout & login again for Docker access"
echo " 2. Open ports 8080 & 9000 in Security Group"
echo "=============================="
