# Kubernetes k3s Installation Guide

## Overview

This guide covers deploying a single-node k3s cluster on Proxmox for learning Kubernetes fundamentals. Future expansion to multi-node cluster is covered at the end.

**What is k3s?**
- Lightweight Kubernetes distribution (certified by CNCF)
- Full Kubernetes functionality in ~70MB binary
- Perfect for homelab, edge computing, IoT
- Easier to deploy and manage than full Kubernetes
- Production-ready (used by major companies)

**Why k3s for Homelab?**
- Learn Kubernetes without cloud costs
- Low resource requirements (runs on 2GB RAM)
- All standard Kubernetes APIs work
- Skills transfer directly to production Kubernetes
- Built-in ingress controller (Traefik)
- Easy upgrade path to full K8s if needed

## Prerequisites

Before starting:
- [ ] Proxmox installed and operational
- [ ] At least one VM created (Ubuntu Server 24.04 recommended)
- [ ] VM has 4GB RAM minimum (8GB recommended)
- [ ] VM has 4 vCPU cores minimum
- [ ] 50GB disk space
- [ ] Static IP configured
- [ ] TrueNAS NFS share available for persistent storage

## Creating the k3s VM

### VM Specifications

**For Single-Node Cluster (Control Plane + Worker):**
- **VM ID:** 500
- **Name:** k3s-control-01
- **OS:** Ubuntu Server 24.04 LTS
- **CPUs:** 4 cores (minimum 2, but 4 recommended)
- **RAM:** 8192 MB (8GB recommended, 4GB minimum)
- **Disk:** 50 GB
- **Network:** vmbr0, Static IP

**Why These Specs?**
- Control plane needs resources for API server, scheduler, etcd
- Worker needs resources for running pods
- Single-node means it does both jobs

### Creating the VM in Proxmox

**Follow standard VM creation** (see [first-vms.md](../04-proxmox/first-vms.md)):

1. Create VM (ID 500, name: k3s-control-01)
2. Install Ubuntu Server 24.04 LTS
3. Configure static IP: 192.168.1.100 (or 192.168.30.50 with VLANs)
4. Install QEMU guest agent
5. Update system: `sudo apt update && sudo apt upgrade -y`

**Additional Configuration:**

```bash
# Set hostname
sudo hostnamectl set-hostname k3s-control-01

# Disable swap (Kubernetes requirement)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install basic tools
sudo apt install -y curl wget vim git htop
```

## Installing k3s (Single-Node)

### Quick Installation

**Default installation (easiest):**
```bash
curl -sfL https://get.k3s.io | sh -
```

That's it! k3s is now running.

**Verify installation:**
```bash
# Check k3s service
sudo systemctl status k3s

# Check nodes (should show this node as Ready)
sudo k3s kubectl get nodes

# Check pods (system pods should be running)
sudo k3s kubectl get pods -A
```

### Custom Installation (Recommended)

**With specific options:**
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --node-name k3s-control-01" sh -
```

**Explanation:**
- `--disable traefik`: Disable built-in Traefik (can install manually later with more control)
- `--write-kubeconfig-mode 644`: Make kubeconfig readable (easier kubectl access)
- `--node-name`: Set specific node name

**Alternative with TLS SAN (for external access):**
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --write-kubeconfig-mode 644 \
  --tls-san k3s.homelab.local \
  --tls-san 192.168.1.100" sh -
```

Adds IP and hostname to TLS certificate (for remote kubectl access).

## Accessing k3s with kubectl

### From k3s VM (Local Access)

**Using k3s kubectl:**
```bash
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
```

**Using kubectl directly (create alias):**
```bash
# Add to ~/.bashrc or ~/.zshrc
echo "alias kubectl='sudo k3s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Now use kubectl normally
kubectl get nodes
kubectl get pods -A
```

### From Your Workstation (Remote Access)

**Copy kubeconfig from k3s VM:**
```bash
# On k3s VM
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy output
```

**On your workstation:**
```bash
# Create .kube directory
mkdir -p ~/.kube

# Create/edit kubeconfig
nano ~/.kube/config

# Paste k3s.yaml content

# IMPORTANT: Change server IP from 127.0.0.1 to VM IP
# Before: server: https://127.0.0.1:6443
# After:  server: https://192.168.1.100:6443
```

**Test remote access:**
```bash
kubectl get nodes
kubectl get pods -A
```

**If using multiple clusters:**
```bash
# View contexts
kubectl config get-contexts

# Switch context
kubectl config use-context default

# Rename context
kubectl config rename-context default homelab-k3s
```

### Installing kubectl on Workstation

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**macOS:**
```bash
brew install kubectl
```

**Windows:**
```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or download from https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

## Configuring TrueNAS Storage for k3s

### Why NFS for Kubernetes?
- Persistent storage for pods (data survives pod restarts)
- Shared storage (multiple pods can access same data)
- Leverages existing TrueNAS infrastructure
- No need for complex Ceph/Longhorn setup (for homelab)

### Creating NFS Share on TrueNAS

**Via TrueNAS Web UI:**

1. **Create Dataset:**
   - Storage → Pools → tank → Add Dataset
   - Name: `kubernetes`
   - Create subdataset: `kubernetes/pvs` (persistent volumes)

2. **Share via NFS:**
   - Shares → Unix (NFS) Shares → Add
   - Path: `/mnt/tank/kubernetes/pvs`
   - Description: "k3s Persistent Volumes"
   - Networks: `192.168.1.0/24` (or your Services VLAN)
   - Maproot User: root
   - Maproot Group: root
   - Save

3. **Enable NFS Service:**
   - System Settings → Services → NFS → Enable
   - Start Automatically: Check

**Test from k3s VM:**
```bash
# Install NFS client
sudo apt install nfs-common -y

# Test mount
sudo mkdir -p /mnt/test
sudo mount -t nfs 192.168.1.10:/mnt/tank/kubernetes/pvs /mnt/test
ls -la /mnt/test
sudo umount /mnt/test
```

### Installing NFS CSI Driver (Automatic Provisioning)

**Option 1: Manual NFS Provisioner**

Create storage class for manual PV creation:

```yaml
# nfs-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-manual
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

Apply:
```bash
kubectl apply -f nfs-storage-class.yaml
```

**Option 2: NFS Subdir External Provisioner (Automatic)**

Automatically creates subdirectories for each PVC.

```bash
# Add Helm repo (install Helm first if needed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add NFS provisioner repo
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Install provisioner
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=192.168.1.10 \
  --set nfs.path=/mnt/tank/kubernetes/pvs \
  --set storageClass.defaultClass=true
```

**Verify:**
```bash
kubectl get storageclass
# Should show nfs-client as default

kubectl get pods -n default
# Should show nfs-subdir-external-provisioner pod running
```

## Deploying Your First Application

### Hello World (nginx)

**Create deployment:**
```yaml
# hello-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-nginx
  template:
    metadata:
      labels:
        app: hello-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

**Create service:**
```yaml
# hello-nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-nginx
spec:
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

**Deploy:**
```bash
kubectl apply -f hello-nginx.yaml
kubectl apply -f hello-nginx-service.yaml

# Check deployment
kubectl get deployments
kubectl get pods
kubectl get services
```

**Access (port-forward for testing):**
```bash
kubectl port-forward service/hello-nginx 8080:80

# Open browser: http://localhost:8080
# Should see nginx welcome page
```

### Application with Persistent Storage

**Create PersistentVolumeClaim:**
```yaml
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client  # or nfs-manual
  resources:
    requests:
      storage: 1Gi
```

**Create pod using PVC:**
```yaml
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "Hello k3s" > /data/hello.txt && sleep 3600']
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
```

**Deploy and verify:**
```bash
kubectl apply -f test-pvc.yaml
kubectl apply -f test-pod.yaml

# Check PVC bound
kubectl get pvc

# Check pod running
kubectl get pods

# Verify data written
kubectl exec test-pod -- cat /data/hello.txt

# Check on TrueNAS
# File should exist in /mnt/tank/kubernetes/pvs/[pvc-folder]/hello.txt
```

## Installing Ingress Controller

### Why Ingress?
- Expose multiple services via single IP
- HTTP/HTTPS routing based on hostname
- TLS termination
- Easier than NodePort or LoadBalancer per service

### Option 1: Traefik (Built-in, Recommended)

If you disabled Traefik during install, re-enable:

```bash
# Reinstall k3s with Traefik enabled
curl -sfL https://get.k3s.io | sh -
```

Or install manually:
```bash
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

### Option 2: Nginx Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml
```

### Creating an Ingress

**Example (using Traefik):**
```yaml
# hello-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-nginx-ingress
spec:
  rules:
  - host: hello.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-nginx
            port:
              number: 80
```

**Deploy:**
```bash
kubectl apply -f hello-ingress.yaml

# Check ingress
kubectl get ingress
```

**Access:**
- Add to `/etc/hosts` or Deco DNS: `192.168.1.100 hello.homelab.local`
- Browse to: `http://hello.homelab.local`

## Monitoring k3s

### Metrics Server (CPU/RAM usage)

k3s includes metrics-server by default.

**Verify:**
```bash
kubectl top nodes
kubectl top pods -A
```

If not working:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Kubernetes Dashboard (Web UI)

**Install:**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

**Create admin user:**
```yaml
# dashboard-admin.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

Apply:
```bash
kubectl apply -f dashboard-admin.yaml
```

**Get access token:**
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

**Access dashboard:**
```bash
kubectl proxy

# Open browser: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
# Login with token
```

### Lens (Desktop App, Highly Recommended)

- Download: https://k8slens.dev/
- Best Kubernetes IDE/dashboard
- Easier than web dashboard
- Multi-cluster support
- Built-in terminal, logs, metrics

## Deploying Real Services to k3s

### Example: Simple Web App (whoami)

```yaml
# whoami.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
spec:
  replicas: 3
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: traefik/whoami:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
spec:
  selector:
    app: whoami
  ports:
  - port: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
spec:
  rules:
  - host: whoami.homelab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
```

**Deploy:**
```bash
kubectl apply -f whoami.yaml

# Add to hosts file: 192.168.1.100 whoami.homelab.local
# Browse to: http://whoami.homelab.local
```

## Expanding to Multi-Node Cluster

### Adding Worker Nodes

**Create additional VMs:**
- **VM ID:** 501, 502, etc.
- **Name:** k3s-worker-01, k3s-worker-02
- **Specs:** 2-4 CPU, 4-8GB RAM, 30GB disk

**On control plane (k3s-control-01), get token:**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

**On worker nodes, join cluster:**
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.100:6443 \
  K3S_TOKEN=<node-token-from-above> sh -
```

**Verify on control plane:**
```bash
kubectl get nodes
# Should show control-01 + worker-01, worker-02
```

### Adding Raspberry Pi Workers (ARM)

Same process as above, k3s automatically detects ARM architecture.

**Note:** Container images must be multi-arch (support ARM64).

## Kubernetes Basics (Cheat Sheet)

### Common Commands

```bash
# Nodes
kubectl get nodes
kubectl describe node k3s-control-01

# Pods
kubectl get pods
kubectl get pods -A  # All namespaces
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow logs
kubectl exec -it <pod-name> -- /bin/bash  # Shell into pod

# Deployments
kubectl get deployments
kubectl scale deployment <name> --replicas=5
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>  # Rollback

# Services
kubectl get services
kubectl get svc  # Short form

# Ingress
kubectl get ingress

# Apply manifests
kubectl apply -f file.yaml
kubectl apply -f directory/  # All files in directory

# Delete resources
kubectl delete -f file.yaml
kubectl delete pod <name>
kubectl delete deployment <name>

# Namespaces
kubectl get namespaces
kubectl create namespace <name>
kubectl get pods -n <namespace>

# Config
kubectl config view
kubectl config get-contexts
kubectl config use-context <context-name>
```

### Understanding Kubernetes Objects

**Pod:** Smallest unit, 1+ containers
**Deployment:** Manages pods, handles scaling and updates
**Service:** Network endpoint for pods (stable IP/DNS)
**Ingress:** HTTP(S) routing to services
**PersistentVolumeClaim:** Request for storage
**ConfigMap:** Configuration data (key-value pairs)
**Secret:** Sensitive data (passwords, tokens)

## Troubleshooting

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods
kubectl describe pod <pod-name>

# Look for:
# - ImagePullBackOff: Wrong image name or no internet
# - CrashLoopBackOff: Container keeps crashing
# - Pending: Not enough resources or PVC not bound
```

**Check logs:**
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Logs from previous crash
```

### Cannot Access Service

**Check service exists:**
```bash
kubectl get svc
```

**Check endpoints:**
```bash
kubectl get endpoints <service-name>
# Should show pod IPs
```

**Test from another pod:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
wget -O- http://<service-name>
```

### PVC Not Binding

**Check PVC status:**
```bash
kubectl get pvc
kubectl describe pvc <pvc-name>
```

**Common issues:**
- StorageClass doesn't exist
- NFS server unreachable
- No space on NFS share

### Node Not Ready

**Check node:**
```bash
kubectl describe node <node-name>

# Look for conditions
```

**On node, check k3s:**
```bash
sudo systemctl status k3s  # Control plane
sudo systemctl status k3s-agent  # Worker
journalctl -u k3s -f  # Logs
```

## Best Practices

1. **Use Namespaces:**
   - Separate environments (dev, test, prod)
   - `kubectl create namespace myapp`
   - Deploy to namespace: `kubectl apply -f app.yaml -n myapp`

2. **Resource Limits:**
   - Set CPU/memory requests and limits
   - Prevents one app from hogging resources

3. **Labels and Selectors:**
   - Organize resources with labels
   - Use selectors to query: `kubectl get pods -l app=myapp`

4. **ConfigMaps and Secrets:**
   - Don't hardcode config in images
   - Use ConfigMaps for config, Secrets for sensitive data

5. **Health Checks:**
   - Define livenessProbe and readinessProbe
   - Kubernetes restarts unhealthy pods

6. **Version Control Manifests:**
   - Store all YAML in Git
   - Track changes
   - Easy rollback

7. **Use Helm for Complex Apps:**
   - Package manager for Kubernetes
   - Pre-built charts for common apps
   - Easier than writing all YAML manually

8. **Monitor Resources:**
   - Use `kubectl top` regularly
   - Set up alerts (Prometheus/Grafana later)

9. **Regular Backups:**
   - Backup etcd (k3s does this automatically)
   - Export important manifests
   - Snapshot k3s VM in Proxmox

10. **Learn kubectl:**
    - Master kubectl commands
    - Use aliases (k=kubectl)
    - Learn kubectl explain for docs

## Next Steps

1. Deploy k3s on Proxmox VM
2. Configure TrueNAS NFS storage
3. Install NFS CSI driver
4. Deploy first application (nginx hello world)
5. Set up ingress controller
6. Deploy a real service (migrate from TrueNAS Docker)
7. Learn GitOps (FluxCD or ArgoCD) for automated deployments
8. Add monitoring (Prometheus + Grafana)
9. Expand to multi-node cluster (optional)

## Learning Resources

- **Official k3s docs:** https://docs.k3s.io/
- **Kubernetes docs:** https://kubernetes.io/docs/
- **Kubernetes Tutorial:** https://kubernetes.io/docs/tutorials/
- **Learn kubectl:** https://kubernetes.io/docs/reference/kubectl/
- **Helm:** https://helm.sh/

---

*Last Updated: 2025-01-26*