#!/bin/bash
set -euo pipefail

CFSSL_VER=1.6.5

# Install cfssl
curl -sLo /usr/local/bin/cfssl \
  https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VER}/cfssl_${CFSSL_VER}_linux_amd64
curl -sLo /usr/local/bin/cfssljson \
  https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VER}/cfssljson_${CFSSL_VER}_linux_amd64
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson

mkdir -p /etc/etcd/pki && cd /etc/etcd/pki

# CA config
cat > ca-config.json <<'EOF'
{"signing":{"default":{"expiry":"87600h"},"profiles":{"etcd":{"expiry":"87600h","usages":["signing","key encipherment","server auth","client auth"]}}}}
EOF

cat > ca-csr.json <<'EOF'
{"CN":"etcd-ca","key":{"algo":"rsa","size":2048}}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Server + peer cert — SANs cover all 3 etcd node IPs
cat > etcd-csr.json <<'EOF'
{"CN":"etcd","hosts":["192.168.1.11","192.168.1.12","192.168.1.13","127.0.0.1","localhost"],"key":{"algo":"rsa","size":2048}}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=etcd \
  etcd-csr.json | cfssljson -bare etcd

# Client cert for RKE2
cat > client-csr.json <<'EOF'
{"CN":"etcd-client","key":{"algo":"rsa","size":2048}}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=etcd \
  client-csr.json | cfssljson -bare client

echo "Certs generated:"
ls -1 /etc/etcd/pki/*.pem

# Distribute to etcd nodes
for NODE in 192.168.1.11 192.168.1.12 192.168.1.13; do
  ssh root@${NODE} "mkdir -p /etc/etcd/pki"
  scp ca.pem etcd.pem etcd-key.pem root@${NODE}:/etc/etcd/pki/
done

# Distribute client cert + CA to RKE2 node
ssh root@192.168.1.20 "mkdir -p /etc/rancher/rke2"
scp ca.pem client.pem client-key.pem root@192.168.1.20:/etc/rancher/rke2/

echo "Done."