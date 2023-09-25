# Kubernetes Lab

A full bells and whistles Kubernetes lab. This will be growing with new features over time.

## Create NGINX Pod with the gVisor RuntimeClass

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - name: nginx
    image: nginx
EOF
```
