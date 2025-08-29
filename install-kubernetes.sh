#!/bin/bash

# install-kubernetes.sh
# Installs vanilla Kubernetes cluster on Ubuntu/Debian systems
# This script should be run BEFORE install-amd-gpu-operator.sh

set -e  # Exit on any error

echo "=============================================="
echo "Vanilla Kubernetes Installation Script"
echo "For AMD GPU Tutorial Prerequisites"
echo "=============================================="

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
KUBERNETES_VERSION="1.28.0-1.1"
CONTAINERD_VERSION="1.7.2"
CALICO_VERSION="v3.26.1"

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS. This script supports Ubuntu/Debian only."
        exit 1
    fi
    
    log_info "Detected OS: $OS $VERSION"
    
    # Check if OS is supported
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        log_error "Unsupported OS: $OS. This script supports Ubuntu/Debian only."
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check for required commands
    for cmd in curl wget apt-get; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is required but not installed"
            exit 1
        fi
    done
    
    # Check available memory (at least 2GB recommended)
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    if [ $MEMORY_GB -lt 2 ]; then
        log_warning "Less than 2GB RAM detected. Kubernetes may not perform well."
    else
        log_success "Memory check passed: ${MEMORY_GB}GB available"
    fi
    
    # Check for AMD GPUs
    if lspci | grep -qi amd; then
        log_success "AMD GPUs detected:"
        lspci | grep -i amd
    else
        log_warning "No AMD GPUs detected. GPU functionality will not be available."
    fi
    
    log_success "Prerequisites check completed."
}

# Function to disable swap (required for Kubernetes)
disable_swap() {
    log_info "Disabling swap (required for Kubernetes)..."
    
    # Disable swap immediately
    swapoff -a
    
    # Disable swap permanently by commenting out swap entries in /etc/fstab
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    log_success "Swap disabled."
}

# Function to configure kernel modules and sysctl settings
configure_kernel() {
    log_info "Configuring kernel modules and sysctl settings..."
    
    # Load required kernel modules
    cat > /etc/modules-load.d/k8s.conf << MODULES_EOF
overlay
br_netfilter
MODULES_EOF

    modprobe overlay
    modprobe br_netfilter
    
    # Configure sysctl settings for Kubernetes
    cat > /etc/sysctl.d/k8s.conf << SYSCTL_EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL_EOF

    # Apply sysctl settings
    sysctl --system
    
    log_success "Kernel configuration completed."
}

# Function to install container runtime (containerd)
install_containerd() {
    log_info "Installing containerd container runtime..."
    
    # Update package index
    apt-get update
    
    # Install required packages
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key (for containerd)
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index with new repository
    apt-get update
    
    # Install containerd
    apt-get install -y containerd.io
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Enable systemd cgroup driver (required for Kubernetes)
    sed -i 's/SystemdCgroup \= false/SystemdCgroup = true/g' /etc/containerd/config.toml
    
    # Enable and start containerd
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd
    
    # Verify containerd is running
    if systemctl is-active --quiet containerd; then
        log_success "containerd installed and running successfully."
    else
        log_error "Failed to start containerd"
        exit 1
    fi
}

# Function to install Kubernetes components
install_kubernetes() {
    log_info "Installing Kubernetes components (kubelet, kubeadm, kubectl)..."
    
    # Install required packages
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update package index
    apt-get update
    
    # Install specific version of Kubernetes components
    apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
    
    # Hold packages to prevent accidental upgrades
    apt-mark hold kubelet kubeadm kubectl
    
    # Enable kubelet service
    systemctl enable kubelet
    
    log_success "Kubernetes components installed successfully."
}

# Function to initialize Kubernetes cluster
initialize_cluster() {
    log_info "Initializing Kubernetes cluster..."
    
    # Get the primary IP address of the node
    NODE_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    log_info "Using node IP: $NODE_IP"
    
    # Initialize the cluster
    kubeadm init \
        --apiserver-advertise-address=$NODE_IP \
        --pod-network-cidr=192.168.0.0/16 \
        --node-name $(hostname -s) \
        --ignore-preflight-errors=NumCPU
    
    # Configure kubectl for the root user
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc
    
    # Also set up for regular users (if they exist)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        USER_HOME=$(eval echo "~$SUDO_USER")
        sudo -u $SUDO_USER mkdir -p $USER_HOME/.kube
        cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
        chown $SUDO_USER:$SUDO_USER $USER_HOME/.kube/config
        
        echo "export KUBECONFIG=$USER_HOME/.kube/config" >> $USER_HOME/.bashrc
        log_info "kubectl configured for user: $SUDO_USER"
    fi
    
    log_success "Kubernetes cluster initialized successfully."
}

# Function to remove taints from control-plane node (for single-node setup)
configure_single_node() {
    log_info "Configuring single-node cluster (removing control-plane taints)..."
    
    # Wait for node to be ready
    sleep 30
    
    # Remove taint from control-plane node to allow scheduling workloads
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
    kubectl taint nodes --all node-role.kubernetes.io/master- || true
    
    log_success "Single-node configuration completed."
}

# Function to install Calico CNI
install_calico() {
    log_info "Installing Calico CNI plugin..."
    
    # Download and apply Calico manifest
    curl -O https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
    kubectl create -f tigera-operator.yaml
    
    # Wait for tigera-operator to be ready
    log_info "Waiting for tigera-operator to be ready..."
    kubectl wait --for=condition=ready pod -l name=tigera-operator -n tigera-operator --timeout=300s
    
    # Create custom resource for Calico
    cat > custom-resources.yaml << CALICO_EOF
# This section includes base Calico installation configuration.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 192.168.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()

---

# This section configures the Calico API server.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
CALICO_EOF

    kubectl create -f custom-resources.yaml
    
    # Wait for Calico to be ready
    log_info "Waiting for Calico to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=calico-node -n calico-system --timeout=600s
    
    # Clean up downloaded files
    rm -f tigera-operator.yaml custom-resources.yaml
    
    log_success "Calico CNI installed successfully."
}

# Function to verify installation
verify_installation() {
    log_info "Verifying Kubernetes installation..."
    
    # Wait for node to be ready
    log_info "Waiting for node to be ready..."
    kubectl wait --for=condition=ready node --all --timeout=300s
    
    # Check cluster status
    log_info "Cluster Information:"
    kubectl cluster-info
    
    echo ""
    log_info "Node Status:"
    kubectl get nodes -o wide
    
    echo ""
    log_info "System Pods Status:"
    kubectl get pods -n kube-system
    
    echo ""
    log_info "Calico Pods Status:"
    kubectl get pods -n calico-system
    
    # Test pod deployment
    log_info "Testing pod deployment..."
    kubectl run test-pod --image=nginx --restart=Never --rm -i --tty -- echo "Kubernetes is working!" || true
    
    log_success "Kubernetes installation verification completed."
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "=============================================="
    log_success "Kubernetes Installation Complete!"
    echo "=============================================="
    echo ""
    echo "✅ Kubernetes cluster is ready for AMD GPU workloads"
    echo ""
    echo "Next steps:"
    echo "1. Run './install-amd-gpu-operator.sh' to install AMD GPU support"
    echo "2. Deploy AI workloads with './deploy-vllm-inference.sh'"
    echo "3. Use the Jupyter notebook for interactive learning"
    echo ""
    echo "Useful commands:"
    echo "• kubectl get nodes                    # Check cluster nodes"
    echo "• kubectl get pods --all-namespaces   # Check all pods"
    echo "• kubectl cluster-info                # Cluster information"
    echo "• kubectl version                     # Kubernetes version"
    echo ""
    echo "KUBECONFIG is set to: /etc/kubernetes/admin.conf"
    echo "Add this to your shell profile for persistence:"
    echo "  echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc"
    echo ""
    log_info "Ready for AMD GPU Operator installation!"
}

# Main execution function
main() {
    echo "Starting Kubernetes installation..."
    echo "Timestamp: $(date)"
    echo ""
    
    detect_os
    echo ""
    
    check_prerequisites
    echo ""
    
    disable_swap
    echo ""
    
    configure_kernel
    echo ""
    
    install_containerd
    echo ""
    
    install_kubernetes
    echo ""
    
    initialize_cluster
    echo ""
    
    configure_single_node
    echo ""
    
    install_calico
    echo ""
    
    verify_installation
    echo ""
    
    show_next_steps
}

# Check if script is run with sudo/root
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run with sudo:"
    echo "sudo $0"
    exit 1
fi

# Run main function
main "$@"
