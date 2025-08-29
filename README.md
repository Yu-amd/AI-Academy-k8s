# Getting Started with Kubernetes on AMD GPUs - Complete Tutorial

This repository contains a comprehensive tutorial for deploying and managing AI inference workloads on Kubernetes clusters with AMD GPUs, based on the [ROCm blog series](https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part1/README.html).

## Repository Structure

```
├── README.md                           # This file
├── kubernetes-amd-gpu-tutorial-outline.md  # Tutorial outline and presentation guide
├── install-amd-gpu-operator.sh         # Script to install AMD GPU Operator
├── deploy-vllm-inference.sh            # Script to deploy vLLM inference workload
├── kubernetes-amd-gpu-demo.ipynb       # Interactive Jupyter notebook demo
└── yaml-configs/                       # Kubernetes YAML configurations
    ├── device-config.yaml              # AMD GPU Operator configuration
    ├── persistent-storage.yaml         # Persistent volume for model storage
    ├── vllm-deployment.yaml            # vLLM inference deployment
    ├── vllm-service.yaml               # LoadBalancer service for vLLM
    ├── metallb-config.yaml             # MetalLB load balancer configuration
    └── gpu-test-pod.yaml               # Simple GPU test pod
```

## Target Audience

Infrastructure administrators and DevOps teams exploring AMD GPUs for production Kubernetes workloads.

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.28+) with nodes that have AMD GPUs
- `kubectl` configured to access your cluster
- AMD GPU drivers installed on cluster nodes
- Helm 3.x installed

### Step 1: Install AMD GPU Operator

```bash
./install-amd-gpu-operator.sh
```

This script will:
- Install Helm (if not present)
- Install cert-manager (prerequisite)
- Install AMD GPU Operator
- Configure device settings for vanilla Kubernetes
- Set up persistent storage for AI models
- Verify the installation

### Step 2: Deploy vLLM AI Inference

```bash
./deploy-vllm-inference.sh
```

This script will:
- Install MetalLB load balancer
- Deploy vLLM inference server with Llama-3.2-1B model
- Create LoadBalancer service for external access
- Generate test scripts for API validation
- Provide scaling demonstration tools

### Step 3: Interactive Tutorial

Open the Jupyter notebook for hands-on exploration:

```bash
jupyter notebook kubernetes-amd-gpu-demo.ipynb
```

The notebook provides interactive sections for:
- Environment verification
- API testing
- Scaling demonstrations
- Troubleshooting exercises

## Tutorial Outline

The complete tutorial follows this structure (suitable for 15-minute presentation):

1. **Fun Intro** (1 minute) - Why Kubernetes + AMD GPUs matter
2. **Agenda** (1 minute) - What we'll cover
3. **Main AI Concept** (4 minutes) - Architecture and benefits
4. **Real-life Applications** - Enterprise use cases
5. **Hands-on Demo** - Installation and deployment
6. **Key Takeaways** - Production considerations
7. **Next Steps** - Advanced topics and resources

## Manual Configuration

If you prefer manual deployment, use the YAML files in `yaml-configs/`:

```bash
# Install AMD GPU Operator first, then apply configurations
kubectl apply -f yaml-configs/device-config.yaml
kubectl apply -f yaml-configs/persistent-storage.yaml
kubectl apply -f yaml-configs/vllm-deployment.yaml
kubectl apply -f yaml-configs/vllm-service.yaml

# For load balancing (adjust IP range in metallb-config.yaml first)
kubectl apply -f yaml-configs/metallb-config.yaml

# For testing GPU functionality
kubectl apply -f yaml-configs/gpu-test-pod.yaml
```

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│                Applications                 │
│  ┌─────────────┐  ┌─────────────┐           │
│  │    vLLM     │  │  Jupyter    │   ...     │
│  │  Inference  │  │ Notebooks   │           │
│  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│            Kubernetes Layer                 │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐    │
│  │   Pods   │ │ Services │ │Deployments│    │
│  └──────────┘ └──────────┘ └───────────┘    │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│           AMD GPU Operator                  │
│  ┌──────────────┐  ┌─────────────────┐      │
│  │Device Plugin │  │  Node Labeller  │      │
│  └──────────────┘  └─────────────────┘      │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│         Hardware Infrastructure             │
│  ┌─────────────────────────────────────┐    │
│  │     AMD Instinct MI300X GPUs        │    │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │    │
│  │  │GPU 0│ │GPU 1│ │GPU 2│ │GPU 3│    │    │
│  │  └─────┘ └─────┘ └─────┘ └─────┘    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

## Verification Commands

After installation, verify your setup:

```bash
# Check AMD GPU Operator
kubectl get pods -n kube-amd-gpu

# Check node GPU labeling
kubectl get nodes -L feature.node.kubernetes.io/amd-gpu

# Check GPU resources
kubectl get nodes -o custom-columns=NAME:.metadata.name,"Total GPUs:.status.capacity.amd\.com/gpu","Allocatable GPUs:.status.allocatable.amd\.com/gpu"

# Check vLLM deployment
kubectl get deployment vllm-inference
kubectl get service vllm-service

# Test GPU functionality
kubectl apply -f yaml-configs/gpu-test-pod.yaml
kubectl exec gpu-test-pod -- rocm-smi
```

## Testing the AI API

Once deployed, test the vLLM API:

```bash
# Get service endpoint
EXTERNAL_IP=$(kubectl get service vllm-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health check
curl http://$EXTERNAL_IP/health

# AI completion test
curl -X POST http://$EXTERNAL_IP/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "microsoft/Llama-3.2-1B-Instruct",
    "prompt": "The benefits of using Kubernetes for AI workloads include:",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## Monitoring and Scaling

### GPU Metrics

If metrics exporter is enabled, access GPU metrics at:
```
http://<node-ip>:32500/metrics
```

### Scaling Operations

```bash
# Scale vLLM deployment
kubectl scale deployment vllm-inference --replicas=2

# Check scaling status
kubectl get deployment vllm-inference
kubectl get pods -l app=vllm-inference
```

## 🔧 Troubleshooting

### Common Issues

1. **GPU resources not showing**:
   ```bash
   kubectl logs -n kube-amd-gpu -l app.kubernetes.io/name=gpu-operator-charts
   ```

2. **vLLM pods not starting**:
   ```bash
   kubectl describe pod -l app=vllm-inference
   kubectl logs -l app=vllm-inference
   ```

3. **LoadBalancer not getting external IP**:
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp
   # Check MetalLB configuration and IP range
   ```

### Useful Commands

- `kubectl get events --sort-by=.metadata.creationTimestamp` - Recent cluster events
- `kubectl describe node <node-name>` - Node resource details
- `kubectl top nodes` - Node resource usage
- `kubectl top pods` - Pod resource usage

## Key Takeaways

1. **Production-Ready Integration**: AMD GPU Operator seamlessly integrates MI300X GPUs with standard Kubernetes
2. **Vanilla Kubernetes Compatible**: No specialized distributions needed - works with standard K8s + Helm
3. **Enterprise Features**: Native scaling, load balancing, and monitoring with cloud-native patterns

## Additional Resources

- **[AMD GPU Operator Documentation](https://rocm.github.io/gpu-operator/)** - Complete configuration reference
- **[ROCm Software Platform](https://rocm.docs.amd.com/)** - AMD's open-source GPU computing stack  
- **[vLLM Documentation](https://docs.vllm.ai/)** - High-performance LLM inference engine
- **[Kubernetes GPU Documentation](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)** - Official GPU scheduling guide
- **[Original ROCm Blog Series](https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part1/README.html)** - Source material for this tutorial

## Getting Help

- **AMD Developer Community**: [community.amd.com](https://community.amd.com)
- **ROCm GitHub Issues**: [github.com/ROCm/ROCm](https://github.com/ROCm/ROCm)
- **Kubernetes Slack**: #sig-node-gpu channel

## License

This tutorial is based on AMD ROCm blog posts and follows open-source best practices. Please refer to individual component licenses for specific terms.

---

**Ready to accelerate your AI workloads with AMD GPUs on Kubernetes?** Start with `./install-amd-gpu-operator.sh` and follow the guide!
