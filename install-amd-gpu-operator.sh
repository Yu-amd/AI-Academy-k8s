#!/bin/bash

# install-amd-gpu-operator.sh
# Installs AMD GPU Operator on vanilla Kubernetes cluster
# Based on ROCm blog series: https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part1/

set -e  # Exit on any error

echo "=============================================="
echo "AMD GPU Operator Installation Script"
echo "Target: Vanilla Kubernetes (not MicroK8s)"
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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed and cluster is accessible
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        log_warning "Helm not found. Installing Helm..."
        install_helm
    fi
    
    # Check for AMD GPUs
    if ! lspci | grep -qi amd; then
        log_warning "No AMD GPUs detected. Script will continue but GPU functionality may not work."
    else
        log_success "AMD GPUs detected:"
        lspci | grep -i amd
    fi
    
    # Display cluster information
    log_info "Cluster Information:"
    kubectl get nodes -o wide
    
    log_success "Prerequisites check completed."
}

# Function to install Helm if not present
install_helm() {
    log_info "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    log_success "Helm installed successfully."
}

# Function to install cert-manager (prerequisite for AMD GPU Operator)
install_cert_manager() {
    log_info "Installing cert-manager..."
    
    # Add Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    
    # Install cert-manager
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.15.1 \
        --set crds.enabled=true \
        --wait --timeout=300s
    
    # Wait for cert-manager to be ready
    log_info "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    log_success "cert-manager installed and ready."
}

# Function to install AMD GPU Operator
install_amd_gpu_operator() {
    log_info "Installing AMD GPU Operator..."
    
    # Add AMD ROCm Helm repository
    helm repo add rocm https://rocm.github.io/gpu-operator --force-update
    helm repo update
    
    # Install the GPU Operator
    helm install amd-gpu-operator rocm/gpu-operator-charts \
        --namespace kube-amd-gpu \
        --create-namespace \
        --wait --timeout=600s
    
    log_success "AMD GPU Operator installed."
}

# Function to create and apply device configuration
configure_device_config() {
    log_info "Creating device configuration..."
    
    # Create device-config.yaml for vanilla Kubernetes
    cat > device-config.yaml << 'CONFIG_EOF'
apiVersion: amd.com/v1alpha1
kind: DeviceConfig
metadata:
  name: gpu-operator
  # use the namespace where AMD GPU Operator is running
  namespace: kube-amd-gpu
spec:
  driver:
    # disable the installation of out-of-tree amdgpu kernel module
    # assuming drivers are already installed on the host
    enable: false

  devicePlugin:
    # Specify the device plugin image
    devicePluginImage: rocm/k8s-device-plugin:latest
    
    # Specify the node labeller image
    nodeLabellerImage: rocm/k8s-device-plugin:labeller-latest
    
    # Enable node labeller for proper GPU detection
    enableNodeLabeller: true
        
  metricsExporter:
    # Enable metrics exporter for monitoring
    enable: true
    # Use NodePort for external access to metrics
    serviceType: "NodePort"
    # Internal service port for metrics collection
    port: 5000
    # Node port for external access
    nodePort: 32500
    # Metrics exporter image
    image: "docker.io/rocm/device-metrics-exporter:v1.0.0"

  # Target nodes with AMD GPUs
  selector:
    feature.node.kubernetes.io/amd-gpu: "true"
CONFIG_EOF

    # Apply the device configuration
    kubectl apply -f device-config.yaml
    
    log_success "Device configuration applied."
}

# Function to verify installation
verify_installation() {
    log_info "Verifying AMD GPU Operator installation..."
    
    # Wait for operator pods to be ready
    log_info "Waiting for GPU operator pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gpu-operator-charts -n kube-amd-gpu --timeout=300s || true
    
    # Check if nodes are properly labeled
    log_info "Checking node labeling..."
    sleep 30  # Give time for node labeler to work
    
    if kubectl get nodes -l feature.node.kubernetes.io/amd-gpu=true --no-headers | wc -l | grep -q "^[1-9]"; then
        log_success "Nodes with AMD GPUs detected and labeled:"
        kubectl get nodes -L feature.node.kubernetes.io/amd-gpu
    else
        log_warning "No nodes with AMD GPU labels found. This may be normal if no AMD GPUs are present."
        kubectl get nodes -L feature.node.kubernetes.io/amd-gpu
    fi
    
    # Check GPU resources
    log_info "Checking GPU resources availability..."
    kubectl get nodes -o custom-columns=NAME:.metadata.name,"Total GPUs:.status.capacity.amd\.com/gpu","Allocatable GPUs:.status.allocatable.amd\.com/gpu" || log_warning "GPU resources not yet available"
    
    # Show operator pods status
    log_info "GPU Operator pods status:"
    kubectl get pods -n kube-amd-gpu
    
    # Show cert-manager pods status
    log_info "cert-manager pods status:"
    kubectl get pods -n cert-manager
}

# Function to create persistent storage for models
setup_persistent_storage() {
    log_info "Setting up persistent storage for AI models..."
    
    # Create PersistentVolume for vanilla Kubernetes
    cat > pv-llama.yaml << 'PV_EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: llama-3.2-1b-pv
  namespace: default
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /mnt/data/llama
  volumeMode: Filesystem
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
PV_EOF

    # Create PersistentVolumeClaim
    cat > pvc-llama.yaml << 'PVC_EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: llama-3.2-1b
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  volumeMode: Filesystem
  storageClassName: local-storage
PVC_EOF

    # Create the directory on the host (assuming single-node cluster)
    sudo mkdir -p /mnt/data/llama
    sudo chmod 777 /mnt/data/llama
    
    # Apply storage manifests
    kubectl apply -f pv-llama.yaml
    kubectl apply -f pvc-llama.yaml
    
    # Verify PVC status
    kubectl get pv,pvc
    
    log_success "Persistent storage configured."
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "=============================================="
    log_success "AMD GPU Operator Installation Complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "1. Run 'deploy-vllm-inference.sh' to deploy AI inference workloads"
    echo "2. Use 'kubectl get nodes -L feature.node.kubernetes.io/amd-gpu' to check GPU node labels"
    echo "3. Use 'kubectl get nodes -o custom-columns=NAME:.metadata.name,\"Total GPUs:.status.capacity.amd\.com/gpu\"' to see GPU resources"
    echo "4. Access GPU metrics at http://<node-ip>:32500/metrics"
    echo ""
    echo "Files created:"
    echo "- device-config.yaml: GPU operator configuration"
    echo "- pv-llama.yaml: Persistent volume for model storage"
    echo "- pvc-llama.yaml: Persistent volume claim"
    echo ""
    echo "Useful commands:"
    echo "- kubectl get pods -n kube-amd-gpu  # Check operator pods"
    echo "- kubectl logs -n kube-amd-gpu <pod-name>  # Check operator logs"
    echo "- kubectl describe node <node-name>  # Check node GPU resources"
    echo ""
}

# Main execution
main() {
    echo "Starting AMD GPU Operator installation..."
    echo "Timestamp: $(date)"
    echo ""
    
    check_prerequisites
    echo ""
    
    install_cert_manager
    echo ""
    
    install_amd_gpu_operator
    echo ""
    
    configure_device_config
    echo ""
    
    setup_persistent_storage
    echo ""
    
    verify_installation
    echo ""
    
    show_next_steps
}

# Run main function
main "$@"
