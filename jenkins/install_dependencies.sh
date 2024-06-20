#!/bin/bash

# Set Debug mode to print out all commands being executed
set -x

## Switch to Root user
echo "${SUDO_PASSWORD}" | sudo -SE su root
whoami

## Check Linux Distribution
sudo lsb_release -a

## Install basic utilities
sudo apt-get update
sudo apt-get install -y curl jq


## Install NodeJS & NPM...
nodejs_version_output=$(node --version 2>&1)
if [ $? -eq 0 ]
then
    echo "NodeJS is already installed"
else
    echo "Installing NodeJS & NPM"
    # Add NodeJS official GPG key
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    sudo chmod a+r /etc/apt/keyrings/nodesource.gpg

    # Add the repository to Apt sources
    NODE_MAJOR=18
    echo \
        "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | \
        sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update

    # Install the latest version
    sudo apt-get install -y nodejs

    # Test to ensure the version installed is as mentioned
    node --version
    npm --version 
fi


## Install Docker...
docker_version_output=$(docker --version 2>&1)
if [ $? -eq 0 ]
then
    echo "Docker is already installed"
else
    echo "Installing Docker"
    # Remove any previously installed unofficial Docker packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove $pkg 
    done
    
    # Add Docker official GPG key
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add the repository to Apt sources
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    
    # Install the latest version
    sudo apt-get install -y docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin

    # Install the container runtime
    sudo apt-get install -y containerd.io

    # Update Containerd Config file for use with Kubernetes
    cat <<EOF | sudo tee -a /etc/containerd/config.toml
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF

    # Enable CRI plugins in the Containerd Config file
    sudo sed -i 's/^disabled_plugins \=/\#disabled_plugins \=/g' /etc/containerd/config.toml

    # Install CNI plugins required for the container runtime to execute
    sudo mkdir -p /opt/cni/bin/
    sudo wget https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz
    sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.0.tgz

    # Restart Containerd 
    sudo systemctl restart containerd

    # Test the installation
    sudo docker run hello-world
fi

    
## Install Kubeadm, Kubelet & Kubectl...
kubectl_version_output=$(kubeadm version && kubelet --version && kubectl version --client 2>&1)
if [ $? -eq 0 ]
then
    echo "Kubeadm, Kubelet & Kubectl are already installed"
else
    echo "Installing Kubeadm, Kubelet & Kubectl"
    # Update the apt package index and install packages needed to use the Kubernetes apt repository
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    
    # Download the public signing key for the Kubernetes package repositories
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add the appropriate Kubernetes apt repository. This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
    echo \
    "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    
    # Finally install kubelet, kubeadm and kubectl. Also, pin their version
    sudo apt-get update
    sudo apt-get install -y kubeadm kubelet kubectl
    sudo apt-mark hold kubeadm kubelet kubectl
    
    # Test to ensure the version installed is as mentioned
    kubeadm version
    kubelet --version
    kubectl version --client
    
    # Verify kubectl configuration by accesing a K8 cluster. Note:- For kubectl to do that, it needs a kubeconfig file located at ~/.kube/config
    kubectl cluster-info
fi


## Install Ansible...
ansible_version_output=$(ansible --version 2>&1)
if [ $? -eq 0 ]
then
    echo "Ansible is already installed"
else
    echo "Installing Ansible"
    # Update the apt package & install necessary packages 
    sudo apt-get update
    sudo apt-get install -y ansible
fi


## Install Terraform...
terraform_version_output=$(terraform --version 2>&1)
if [ $? -eq 0 ]
then
    echo "Terraform is already installed"
else
    echo "Installing Terraform"
    # Add the HashiCorp GPG key
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    # Add the HashiCorp repository
    echo \
    "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

    # Finally install terraform 
    sudo apt-get update
    sudo apt-get install -y terraform
fi


## Install Google Cloud SDK...
gcloud_version_output=$(gcloud version 2>&1)
if [ $? -eq 0 ]
then
    echo "Google Cloud SDK is already installed"
else
    echo "Installing Google Cloud SDK"
    # Update the apt package & install necessary packages 
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates gnupg curl sudo

    ########
    ## Add the appropriate Google Cloud apt repository. Only one of the below options shall be executed.
    ########

    # If your distribution supports the signed-by option, run the following command
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

    # If your distribution doesn't support the signed-by option, run the following command
    echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

    ########
    ## Import the Google Cloud public key. Only one of the below options shall be executed.
    ########
    # If your distribution's apt-key command supports the --keyring argument, run the following command
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

    # If your distribution's apt-key command doesn't support the --keyring argument, run the following command
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    # If your distribution (Debian 11+ or Ubuntu 21.10+) doesn't support apt-key, run the following command
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc

    # Finally install Google Cloud SDK
    sudo apt-get update
    sudo apt-get install -y google-cloud-cli

    # Test to ensure the version installed is as mentioned
    gcloud version 

    # Following commands to be executed outside of this Jenkinsfile for initializing & configuring Google Cloud SDK
    # gcloud auth login
    # gcloud init
fi

## Switch back to default user
exit