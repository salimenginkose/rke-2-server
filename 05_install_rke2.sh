#!/bin/bash
set -euo pipefail

curl -sfL https://get.rke2.io | sh -

mkdir -p /etc/rancher/rke2

cat > /etc/rancher/rke2/config.yaml <<'EOF'
datastore-endpoint: "https://192.168.1.11:2379,https://192.168.1.12:2379,https://192.168.1.13:2379"
datastore-cafile: "/etc/rancher/rke2/ca.pem"
datastore-certfile: "/etc/rancher/rke2/client.pem"
datastore-keyfile: "/etc/rancher/rke2/client-key.pem"
EOF

systemctl enable --now rke2-server

echo "Waiting 120s for RKE2 to come up..."
sleep 120

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
/var/lib/rancher/rke2/bin/kubectl get nodes