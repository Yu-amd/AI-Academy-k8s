#!/bin/bash

#==============================================
# Container-Compatible Kubernetes Installation Script
# For AMD GPU Tutorial Prerequisites (Docker/Container Environment)
#==============================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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
    exit 1
}

print_banner() {
    echo "=============================================="
    echo "Container-Compatible Kubernetes Installation"
    echo "For AMD GPU Tutorial Prerequisites"
    echo "=============================================="
    echo "Starting Kubernetes installation..."
    echo "Timestamp: $(date)"
    echo ""
}

check_container_environment() {
    log_info "Checking container environment compatibility..."
    
    # Check if running in container
    if [ -f /.dockerenv ] || grep -sq 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        log_warning "Running in container environment - some features will be adapted"
        export CONTAINER_ENV=true
    else
        export CONTAINER_ENV=false
    fi
    
    # Check for systemd
    if ! pidof systemd > /dev/null 2>&1; then
        log_warning "systemd not available - using alternative approach"
        export NO_SYSTEMD=true
    else
        export NO_SYSTEMD=false
    fi
    
    log_success "Environment check completed"
}

# Function to check if command exists
check_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install kubectl tools
install_kubectl_tools() {
    log_info "Installing Kubernetes client tools..."
    
    # Wait for package manager
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        sleep 2
    done
    
    # Install prerequisites
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    
    # Add Kubernetes repository
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
    
    apt-get update
    apt-get install -y kubectl=1.28.0-1.1 kubeadm=1.28.0-1.1
    apt-mark hold kubectl kubeadm
    
    log_success "Kubernetes client tools installed."
}

# Install kind for local Kubernetes
install_kind() {
    log_info "Installing kind (Kubernetes in Docker)..."
    
    # Install Docker if not present
    if ! check_command_exists docker; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    
    # Install kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    
    log_success "kind installed successfully."
}

# Create kind cluster
create_kind_cluster() {
    log_info "Creating kind cluster for container environment..."
    
    # Create kind config for GPU support
    cat > kind-config.yaml << YAML_EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /dev
    containerPath: /dev
  - hostPath: /sys
    containerPath: /sys
    readOnly: true
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
YAML_EOF

    # Create the cluster
    kind create cluster --config=kind-config.yaml --name amd-gpu-cluster
    
    # Set kubectl context
    kubectl cluster-info --context kind-amd-gpu-cluster
    
    log_success "kind cluster created successfully."
}

# Main function for container environment
main() {
    print_banner
    
    check_container_environment
    
    log_info "Container environment detected - installing kubectl tools and kind..."
    install_kubectl_tools
    
    # Check if Docker is available for kind
    if check_command_exists docker || [ -S /var/run/docker.sock ]; then
        install_kind
        create_kind_cluster
    else
        log_warning "Docker not available - installing kubectl tools only"
        log_info "To create a cluster, use an external Kubernetes service or run on host system"
    fi
    
    echo ""
    log_success "Container-compatible Kubernetes setup completed!"
    echo ""
    log_info "Next steps:"
    log_info "• Verify cluster: kubectl get nodes"
    log_info "• Deploy applications: kubectl apply -f your-manifests.yaml"
    log_info "• Access services: kubectl get services"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)."
fi

# Run main function
main "$@"
