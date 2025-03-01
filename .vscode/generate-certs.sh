#!/bin/bash
set -euo pipefail

# Get the .vscode directory path
VSCODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${VSCODE_DIR}"

# Check if certificates already exist
if [ -f dev-certs/ca.crt ] && [ -f dev-certs/apiserver.crt ] && [ -f dev-certs/admin.crt ] && [ -f dev-kubeconfig ]; then
    echo "Certificates already exist, skipping generation."
    exit 0
fi

echo "Generating certificates..."

# Create directories
mkdir -p dev-certs
cd dev-certs

# Generate CA key and certificate
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=kubernetes" -days 365 -out ca.crt

# Generate API server key and certificate
openssl genrsa -out apiserver.key 2048

# Create OpenSSL config for SANs
cat > apiserver.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 127.0.0.1
DNS.5 = localhost
EOF

openssl req -new -key apiserver.key -subj "/CN=kube-apiserver" -out apiserver.csr -config apiserver.cnf
openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -days 365 -extensions v3_req -extfile apiserver.cnf

# Generate admin client certificate (with system:masters group)
openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=kubernetes-admin/O=system:masters" -out admin.csr
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.crt -days 365

# Generate service account key pair
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub

# Create a basic kubeconfig with absolute paths
cat > ../dev-kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${PWD}/ca.crt
    server: https://localhost:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate: ${PWD}/admin.crt
    client-key: ${PWD}/admin.key
EOF

chmod 600 ../dev-kubeconfig

echo "Certificate generation complete." 