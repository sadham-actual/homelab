# ADR-0002: Use k3s Instead of Full Kubernetes

**Date:** 2025-01-26

**Status:** Accepted

### Context

Goal is to learn Kubernetes and run container orchestration in homelab. Need to choose between:
- Full Kubernetes (kubeadm, kops, etc.)
- k3s (lightweight Kubernetes)
- k0s (alternative lightweight)
- Docker Swarm
- Nomad

Constraints:
- Limited hardware resources (Dell 3080 Micro with 6 cores, 40GB RAM)
- Learning environment (not production)
- Want skills transferable to production Kubernetes
- Ease of deployment and maintenance matters

### Decision

**Deploy k3s as the Kubernetes distribution** for the homelab.

Start with single-node cluster on Proxmox VM, with option to expand to multi-node later (additional VMs or Raspberry Pis).

### Consequences

**Positive:**
- Easy installation (single curl command)
- Low resource overhead (~512MB RAM for control plane)
- Full Kubernetes API compatibility (certified by CNCF)
- Skills transfer directly to production Kubernetes
- Built-in components (Traefik ingress, CoreDNS, local storage)
- Active development and strong community
- Perfect for homelab and edge computing
- Can expand to multi-node easily

**Negative:**
- Slightly different defaults than full K8s (e.g., uses sqlite by default instead of etcd)
- Some advanced features removed (not relevant for homelab)
- Less enterprise adoption than full Kubernetes (but growing)

**Neutral:**
- Upgrade path to full K8s exists if needed (unlikely)

### Alternatives Considered

**Full Kubernetes (kubeadm):**
- Pros: Industry standard, what enterprises use
- Cons: Complex setup, higher resource usage, overkill for homelab
- Why rejected: Too heavy for homelab resources, adds complexity without benefit

**Docker Swarm:**
- Pros: Simple, built into Docker, easy to learn
- Cons: Less feature-rich, declining adoption, skills don't transfer to K8s
- Why rejected: Industry moving away from Swarm toward Kubernetes

**k0s:**
- Pros: Similar to k3s, zero dependencies
- Cons: Smaller community, less mature
- Why rejected: k3s has larger community and better documentation

**Nomad:**
- Pros: Very simple, HashiCorp ecosystem
- Cons: Not Kubernetes, different paradigm, skills don't transfer
- Why rejected: Want to learn actual Kubernetes

---