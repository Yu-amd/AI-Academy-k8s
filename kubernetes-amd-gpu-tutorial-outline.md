# Getting Started with Kubernetes on AMD GPUs

**Target Audience**: Infrastructure administrators and DevOps teams exploring AMD GPUs for production Kubernetes workloads

---

## Fun Intro (1 minute)

Welcome to the future of AI infrastructure! Imagine deploying large language models that can process thousands of requests per second, running complex scientific simulations, or powering real-time AI applications - all orchestrated seamlessly across your Kubernetes cluster with AMD's cutting-edge MI300X GPUs. 

In just the next 15 minutes, you'll transform from curious observer to confident practitioner, ready to harness the full power of AMD GPU acceleration in your production Kubernetes environment. Let's dive into the world where enterprise-grade AI meets cloud-native orchestration!

## Agenda (1 minute)

1. **Understanding the AI Infrastructure Landscape** - Why Kubernetes + AMD GPUs = Production Ready AI
2. **Hands-on Setup** - From zero to GPU-accelerated cluster in minutes
3. **Real-world Deployment** - Deploy and scale vLLM inference workloads
4. **Production Considerations** - Load balancing, monitoring, and best practices
5. **Your Next Steps** - Taking this knowledge to production

## Explain Main AI Concept (4 minutes)

### The Modern AI Infrastructure Challenge

Organizations today face a critical challenge: **How do you scale AI inference workloads efficiently while maintaining reliability, cost-effectiveness, and operational simplicity?**

**Traditional Approach Problems:**
- Manual GPU resource management
- Inconsistent deployment environments  
- Difficult scaling and load balancing
- Limited observability and monitoring

**The Kubernetes + AMD GPU Solution:**

**Kubernetes** provides the orchestration layer that automates:
- **Resource Allocation**: Intelligent scheduling of workloads across GPU nodes
- **Scaling**: Automatic horizontal and vertical scaling based on demand
- **Reliability**: Self-healing deployments with health checks and restarts
- **Portability**: Consistent deployments across development, staging, and production

**AMD Instinct MI300X GPUs** deliver:
- **192GB HBM3 Memory**: Handle the largest language models without memory constraints
- **Performance**: Up to 1.3x better performance per dollar compared to competitors
- **ROCm Ecosystem**: Open-source software stack with excellent Kubernetes integration

**The AMD GPU Operator** bridges these technologies by:
- Automatically detecting AMD GPUs in your cluster
- Installing necessary drivers and runtime components
- Exposing GPUs as schedulable Kubernetes resources
- Providing metrics and monitoring capabilities

### Key Architecture Components

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

## Real-life Applications

### Enterprise AI Inference at Scale
**Scenario**: Financial services company processing 100,000+ fraud detection requests per minute
- **Challenge**: Sub-100ms response time requirements with 99.99% uptime
- **Solution**: Kubernetes auto-scaling across 8x MI300X GPUs with load balancing
- **Result**: 40% cost reduction while meeting performance SLAs

### Scientific Computing Workloads  
**Scenario**: Research institution running climate modeling simulations
- **Challenge**: Unpredictable workload patterns, resource contention
- **Solution**: Kubernetes resource quotas and priority classes for job scheduling
- **Result**: 3x improvement in cluster utilization and researcher productivity

### Multi-Tenant AI Platform
**Scenario**: Cloud provider offering AI-as-a-Service to customers
- **Challenge**: Secure isolation, resource allocation, billing accuracy
- **Solution**: Kubernetes namespaces with GPU resource limits and monitoring
- **Result**: Enabled 50+ concurrent customers with predictable performance

## Demonstrate How to Create/Run

### Installation

**Prerequisites Check:**
```bash
# Verify you have a Kubernetes cluster (v1.28+)
kubectl version --client
kubectl cluster-info

# Check node readiness
kubectl get nodes

# Verify GPU hardware detection
lspci | grep -i amd
```

### Run Scripts

**Phase 1: Infrastructure Setup** (See `install-amd-gpu-operator.sh`)
**Phase 2: Deploy AI Workload** (See `deploy-vllm-inference.sh`) 
**Phase 3: Interactive Development** (See `kubernetes-amd-gpu-demo.ipynb`)

## 3 Key Takeaways

1. **AMD GPU + Kubernetes = Production-Ready AI Infrastructure**
   - The AMD GPU Operator seamlessly integrates MI300X GPUs into your existing Kubernetes clusters
   - Native Kubernetes scheduling and scaling capabilities work automatically with GPU resources
   - 192GB HBM3 memory enables deployment of the largest language models without complex model sharding

2. **Vanilla Kubernetes Works Out-of-the-Box**
   - No need for specialized distributions - standard Kubernetes + Helm charts provide everything needed
   - Persistent volumes enable efficient model caching and reduced startup times
   - Standard Kubernetes networking and service discovery work seamlessly with GPU workloads

3. **Operational Excellence Through Cloud-Native Patterns**
   - MetalLB provides enterprise-grade load balancing for inference endpoints
   - Horizontal Pod Autoscaling automatically manages capacity based on demand
   - Prometheus metrics and Grafana dashboards provide complete observability into GPU utilization

## Next Steps and Additional Resources

### Immediate Next Steps
1. **Pilot Deployment**: Start with a single-node cluster to validate your specific workloads
2. **Performance Benchmarking**: Use the included scripts to benchmark your models and establish baselines  
3. **Production Planning**: Design your multi-node architecture considering networking, storage, and security requirements

### Advanced Topics to Explore
- **Multi-GPU Model Parallelism**: Deploying models larger than single GPU memory
- **Custom Resource Scheduling**: Advanced GPU allocation strategies for mixed workloads
- **Security Hardening**: Pod security policies and network segmentation for production
- **Cost Optimization**: Spot instances, preemptible workloads, and resource right-sizing

### Documentation and Community Resources
- **[AMD GPU Operator Documentation](https://rocm.github.io/gpu-operator/)** - Complete configuration reference
- **[ROCm Software Platform](https://rocm.docs.amd.com/)** - AMD's open-source GPU computing stack

### Getting Help
- **AMD Developer Community**: [community.amd.com](https://community.amd.com)
- **ROCm GitHub Issues**: [github.com/ROCm/ROCm](https://github.com/ROCm/ROCm)

---

**Ready to get started?** Let's move to the hands-on installation and deployment scripts!
