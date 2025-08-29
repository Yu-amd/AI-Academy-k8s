#!/bin/bash

# deploy-vllm-inference.sh
# Deploys vLLM inference server with MetalLB load balancing on vanilla Kubernetes
# Based on ROCm blog series: https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part2/

set -e  # Exit on any error

echo "=============================================="
echo "vLLM AI Inference Deployment Script"
echo "Target: Vanilla Kubernetes with AMD GPUs"
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
    
    # Check if AMD GPU Operator is installed
    if ! kubectl get namespace kube-amd-gpu &> /dev/null; then
        log_error "AMD GPU Operator not found. Please run install-amd-gpu-operator.sh first."
        exit 1
    fi
    
    # Check if nodes have GPU resources
    GPU_NODES=$(kubectl get nodes -o custom-columns=NAME:.metadata.name,"GPUs:.status.capacity.amd\.com/gpu" --no-headers | grep -v '<none>' | wc -l)
    if [ "$GPU_NODES" -eq 0 ]; then
        log_warning "No nodes with AMD GPU resources found. Deployment may fail."
    else
        log_success "Found $GPU_NODES node(s) with AMD GPU resources."
    fi
    
    log_success "Prerequisites check completed."
}

# Function to install MetalLB load balancer
install_metallb() {
    log_info "Installing MetalLB load balancer..."
    
    # Check if MetalLB is already installed
    if kubectl get namespace metallb-system &> /dev/null; then
        log_info "MetalLB already installed. Skipping installation."
        return 0
    fi
    
    # Install MetalLB using manifests
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB pods to be ready
    log_info "Waiting for MetalLB to be ready..."
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=90s
    
    log_success "MetalLB installed successfully."
}

# Function to configure MetalLB IP pool
configure_metallb() {
    log_info "Configuring MetalLB IP address pool..."
    
    # Get the node's IP to calculate safe IP range
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    log_info "Detected node IP: $NODE_IP"
    
    # Calculate IP range (using .240-.250 range for safety)
    IP_PREFIX=$(echo $NODE_IP | cut -d. -f1-3)
    IP_RANGE="${IP_PREFIX}.240-${IP_PREFIX}.250"
    
    log_info "Using IP range: $IP_RANGE"
    
    # Create MetalLB configuration
    cat > metallb-config.yaml << CONFIG_EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
CONFIG_EOF

    # Apply MetalLB configuration
    kubectl apply -f metallb-config.yaml
    
    log_success "MetalLB configured with IP range: $IP_RANGE"
}

# Function to deploy vLLM inference server
deploy_vllm() {
    log_info "Deploying vLLM inference server..."
    
    # Create vLLM deployment manifest
    cat > vllm-deployment.yaml << 'VLLM_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-inference
  namespace: default
  labels:
    app: vllm-inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-inference
  template:
    metadata:
      labels:
        app: vllm-inference
    spec:
      containers:
      - name: vllm-container
        image: rocm/vllm:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: HUGGING_FACE_HUB_TOKEN
          value: ""  # Add your HF token if needed for gated models
        command:
        - "python"
        - "-m"
        - "vllm.entrypoints.openai.api_server"
        args:
        - "--model"
        - "microsoft/Llama-3.2-1B-Instruct"  # Small model for demo
        - "--host"
        - "0.0.0.0"
        - "--port"
        - "8000"
        - "--download-dir"
        - "/models"
        - "--tensor-parallel-size"
        - "1"
        volumeMounts:
        - name: model-storage
          mountPath: /models
        resources:
          requests:
            amd.com/gpu: 1
            memory: "8Gi"
            cpu: "2"
          limits:
            amd.com/gpu: 1
            memory: "16Gi"
            cpu: "4"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 30
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: llama-3.2-1b
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      - key: amd.com/gpu
        operator: Exists
        effect: NoSchedule
VLLM_EOF

    # Apply vLLM deployment
    kubectl apply -f vllm-deployment.yaml
    
    log_success "vLLM deployment created."
}

# Function to create vLLM service with LoadBalancer
create_vllm_service() {
    log_info "Creating vLLM service with LoadBalancer..."
    
    # Create service manifest
    cat > vllm-service.yaml << 'SERVICE_EOF'
apiVersion: v1
kind: Service
metadata:
  name: vllm-service
  namespace: default
  labels:
    app: vllm-inference
spec:
  type: LoadBalancer
  selector:
    app: vllm-inference
  ports:
  - port: 80
    targetPort: 8000
    protocol: TCP
    name: http
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: api
SERVICE_EOF

    # Apply service
    kubectl apply -f vllm-service.yaml
    
    log_success "vLLM service created."
}

# Function to wait for deployment and get access information
wait_and_verify() {
    log_info "Waiting for vLLM deployment to be ready..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available deployment/vllm-inference --timeout=600s
    
    # Wait for service to get external IP
    log_info "Waiting for LoadBalancer to assign external IP..."
    EXTERNAL_IP=""
    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get service vllm-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            break
        fi
        echo "Waiting for external IP... (attempt $i/30)"
        sleep 10
    done
    
    if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
        log_warning "External IP not assigned. Using NodePort or port-forward to access the service."
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        echo "You can access the service using port-forward:"
        echo "kubectl port-forward service/vllm-service 8000:8000"
        echo "Then access http://localhost:8000"
    else
        log_success "vLLM service is accessible at: http://$EXTERNAL_IP"
        echo "API endpoint: http://$EXTERNAL_IP/v1/completions"
        echo "Health check: http://$EXTERNAL_IP/health"
    fi
}

# Function to create test scripts
create_test_scripts() {
    log_info "Creating test scripts..."
    
    # Create a simple test script
    cat > test-vllm-api.sh << 'TEST_EOF'
#!/bin/bash

# test-vllm-api.sh - Test vLLM API endpoint

# Get service endpoint
EXTERNAL_IP=$(kubectl get service vllm-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
    echo "Using port-forward for testing..."
    kubectl port-forward service/vllm-service 8000:8000 &
    PORT_FORWARD_PID=$!
    sleep 5
    ENDPOINT="http://localhost:8000"
else
    ENDPOINT="http://$EXTERNAL_IP"
fi

echo "Testing vLLM API at: $ENDPOINT"

# Test health endpoint
echo "1. Testing health endpoint..."
curl -s "$ENDPOINT/health" | jq . || echo "Health check response received"

echo -e "\n2. Testing completions endpoint..."
# Test completions endpoint
curl -X POST "$ENDPOINT/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "microsoft/Llama-3.2-1B-Instruct",
        "prompt": "Explain the benefits of using Kubernetes for AI workloads:",
        "max_tokens": 100,
        "temperature": 0.7
    }' | jq .

# Cleanup port-forward if used
if [ -n "$PORT_FORWARD_PID" ]; then
    kill $PORT_FORWARD_PID 2>/dev/null
fi
TEST_EOF

    chmod +x test-vllm-api.sh
    
    # Create scaling demonstration script
    cat > scale-vllm.sh << 'SCALE_EOF'
#!/bin/bash

# scale-vllm.sh - Demonstrate scaling vLLM deployment

echo "Current vLLM deployment status:"
kubectl get deployment vllm-inference

echo -e "\nScaling to 2 replicas..."
kubectl scale deployment vllm-inference --replicas=2

echo "Waiting for scaling to complete..."
kubectl wait --for=condition=available deployment/vllm-inference --timeout=300s

echo -e "\nUpdated deployment status:"
kubectl get deployment vllm-inference
kubectl get pods -l app=vllm-inference

echo -e "\nTo scale back to 1 replica:"
echo "kubectl scale deployment vllm-inference --replicas=1"
SCALE_EOF

    chmod +x scale-vllm.sh
    
    log_success "Test scripts created: test-vllm-api.sh, scale-vllm.sh"
}

# Function to display deployment information
show_deployment_info() {
    echo ""
    echo "=============================================="
    log_success "vLLM Deployment Complete!"
    echo "=============================================="
    echo ""
    
    echo "Deployment Status:"
    kubectl get deployment vllm-inference
    echo ""
    
    echo "Service Information:"
    kubectl get service vllm-service
    echo ""
    
    echo "Pod Status:"
    kubectl get pods -l app=vllm-inference
    echo ""
    
    echo "GPU Resource Usage:"
    kubectl describe nodes | grep -A 5 "amd.com/gpu" || echo "GPU resources not visible in describe output"
    echo ""
    
    echo "Files created:"
    echo "- vllm-deployment.yaml: vLLM inference server deployment"
    echo "- vllm-service.yaml: LoadBalancer service for vLLM"
    echo "- metallb-config.yaml: MetalLB load balancer configuration"
    echo "- test-vllm-api.sh: Script to test the API"
    echo "- scale-vllm.sh: Script to demonstrate scaling"
    echo ""
    
    echo "Useful commands:"
    echo "- kubectl get pods -l app=vllm-inference  # Check vLLM pods"
    echo "- kubectl logs -l app=vllm-inference  # Check vLLM logs"
    echo "- kubectl port-forward service/vllm-service 8000:8000  # Access via port-forward"
    echo "- ./test-vllm-api.sh  # Test the API"
    echo "- ./scale-vllm.sh  # Scale the deployment"
    echo ""
}

# Main execution
main() {
    echo "Starting vLLM inference deployment..."
    echo "Timestamp: $(date)"
    echo ""
    
    check_prerequisites
    echo ""
    
    install_metallb
    echo ""
    
    configure_metallb
    echo ""
    
    deploy_vllm
    echo ""
    
    create_vllm_service
    echo ""
    
    wait_and_verify
    echo ""
    
    create_test_scripts
    echo ""
    
    show_deployment_info
}

# Run main function
main "$@"
