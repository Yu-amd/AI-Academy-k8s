# Getting Started with Kubernetes on AMD GPUs - Complete Tutorial

This repository contains a comprehensive tutorial for deploying and managing AI inference workloads on Kubernetes clusters with AMD GPUs, based on the [ROCm blog series](https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part1/README.html).

## 📁 Repository Structure

```
├── README.md                           # This file
├── kubernetes-amd-gpu-tutorial-outline.md  # Tutorial outline and presentation guide
├── install-kubernetes.sh               # Script to install vanilla Kubernetes (if needed)
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

## 🎯 Target Audience

Infrastructure administrators and DevOps teams exploring AMD GPUs for production Kubernetes workloads.

## 🚀 Quick Start

### Prerequisites

- Ubuntu/Debian server with AMD GPUs
- Root/sudo access
- At least 2GB RAM and 20GB free disk space
- Internet connectivity for package downloads

### Complete Installation from Scratch

#### Step 0: Install Kubernetes (if you don't have it already)

```bash
sudo ./install-kubernetes.sh
```

This script will:
- Install vanilla Kubernetes 1.28+ on Ubuntu/Debian
- Configure containerd container runtime
- Set up Calico CNI networking
- Configure single-node cluster (removes control-plane taints)
- Disable swap and configure kernel settings
- Verify cluster functionality

#### Step 1: Install AMD GPU Operator

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

#### Step 2: Deploy vLLM AI Inference

```bash
./deploy-vllm-inference.sh
```

This script will:
- Install MetalLB load balancer
- Deploy vLLM inference server with Llama-3.2-1B model
- Create LoadBalancer service for external access
- Generate test scripts for API validation
- Provide scaling demonstration tools

#### Step 3: Interactive Tutorial

Open the Jupyter notebook for hands-on exploration:

```bash
jupyter notebook kubernetes-amd-gpu-demo.ipynb
```

The notebook provides interactive sections for:
- Kubernetes prerequisite checks and installation
- Environment verification
- API testing
- Scaling demonstrations
- Troubleshooting exercises

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────┐
│                Applications                 │
│  ┌─────────────┐  ┌─────────────┐         │
│  │    vLLM     │  │  Jupyter    │   ...   │
│  │  Inference  │  │ Notebooks   │         │
│  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│            Kubernetes Layer                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │   Pods   │ │ Services │ │Deployments│   │
│  └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│           AMD GPU Operator                  │
│  ┌──────────────┐  ┌─────────────────┐     │
│  │Device Plugin │  │  Node Labeller  │     │
│  └──────────────┘  └─────────────────┘     │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│         Hardware Infrastructure             │
│  ┌─────────────────────────────────────┐   │
│  │     AMD Instinct MI300X GPUs        │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │   │
│  │  │GPU 0│ │GPU 1│ │GPU 2│ │GPU 3│   │   │
│  │  └─────┘ └─────┘ └─────┘ └─────┘   │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## 🎓 Key Takeaways

1. **Complete Stack from Bare Metal**: Single-script installation from fresh Ubuntu to production GPU cluster
2. **Vanilla Kubernetes Compatible**: No specialized distributions needed - works with standard K8s + Helm
3. **Enterprise Features**: Native scaling, load balancing, and monitoring with cloud-native patterns

## 📚 Additional Resources

- **[AMD GPU Operator Documentation](https://rocm.github.io/gpu-operator/)** - Complete configuration reference
- **[ROCm Software Platform](https://rocm.docs.amd.com/)** - AMD's open-source GPU computing stack  
- **[vLLM Documentation](https://docs.vllm.ai/)** - High-performance LLM inference engine
- **[Kubernetes GPU Documentation](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)** - Official GPU scheduling guide
- **[Original ROCm Blog Series](https://rocm.blogs.amd.com/artificial-intelligence/k8s-orchestration-part1/README.html)** - Source material for this tutorial

## 🆘 Getting Help

- **AMD Developer Community**: [community.amd.com](https://community.amd.com)
- **ROCm GitHub Issues**: [github.com/ROCm/ROCm](https://github.com/ROCm/ROCm)
- **Kubernetes Slack**: #sig-node-gpu channel

---

**Ready to accelerate your AI workloads with AMD GPUs on Kubernetes?** 

**New to Kubernetes?** Start with `sudo ./install-kubernetes.sh`  
**Have Kubernetes already?** Jump to `./install-amd-gpu-operator.sh`

🚀 From bare metal to AI in minutes!
