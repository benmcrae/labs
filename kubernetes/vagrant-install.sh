# Disable swap space
swapoff -a
sed -i 's|/swap.*|#|' /etc/fstab

# Install prerequisite
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# Enable system modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF
modprobe br_netfilter
modprobe overlay

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.arm64
install -m 755 runc.arm64 /usr/local/sbin/runc

# Install gVisor (runsc)
wget https://storage.googleapis.com/gvisor/releases/release/latest/aarch64/runsc
wget https://storage.googleapis.com/gvisor/releases/release/latest/aarch64/containerd-shim-runsc-v1
chmod a+rx runsc containerd-shim-runsc-v1
mv runsc containerd-shim-runsc-v1 /usr/local/bin

# Install containerd
wget https://github.com/containerd/containerd/releases/download/v1.7.8/containerd-1.7.8-linux-arm64.tar.gz
tar Cxzvf /usr/local containerd-1.7.8-linux-arm64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service

# Configure containerd
mkdir -p /etc/containerd/
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
cat >> /etc/containerd/config.toml << EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd

# Start containerd
systemctl daemon-reload
systemctl enable --now containerd

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-arm64-v1.3.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-arm64-v1.3.0.tgz

# Install nerdctl
wget https://github.com/containerd/nerdctl/releases/download/v1.7.0/nerdctl-1.7.0-linux-arm64.tar.gz
tar -xzvv -C /usr/local/bin -f nerdctl-1.7.0-linux-arm64.tar.gz nerdctl

# Install Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure Kubernetes
kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Allow workloads to run on the control plane node
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Create RuntimeClass for gVisor
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF

# Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
