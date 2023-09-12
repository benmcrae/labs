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
wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# Install containerd
wget https://github.com/containerd/containerd/releases/download/v1.7.6/containerd-1.7.6-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.6-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /lib/systemd/system/containerd.service

# Configure containerd
mkdir -p /etc/containerd/
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd

# Start containerd
systemctl daemon-reload
systemctl enable --now containerd

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz

# Install nerdctl
wget https://github.com/containerd/nerdctl/releases/download/v1.5.0/nerdctl-1.5.0-linux-amd64.tar.gz
tar -xzvv -C /usr/local/bin -f nerdctl-1.5.0-linux-amd64.tar.gz nerdctl

# Install gVisor (runcs)
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/containerd-shim-runsc-v1
chmod a+rx runsc containerd-shim-runsc-v1
mv runsc containerd-shim-runsc-v1 /usr/local/bin
