#!/bin/bash
# Usage: bash 03_configure_etcd.sh 1   (for etcd-1)
#        bash 03_configure_etcd.sh 2   (for etcd-2)
#        bash 03_configure_etcd.sh 3   (for etcd-3)
set -euo pipefail

NODE_NUM=${1:?'Pass node number: 1, 2, or 3'}
NODE_NAME="etcd-${NODE_NUM}"
NODE_IP="192.168.1.1${NODE_NUM}"

cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
After=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${NODE_NAME} \\
  --data-dir /var/lib/etcd \\
  --listen-peer-urls https://${NODE_IP}:2380 \\
  --listen-client-urls https://${NODE_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODE_IP}:2379 \\
  --initial-advertise-peer-urls https://${NODE_IP}:2380 \\
  --initial-cluster etcd-1=https://192.168.1.11:2380,etcd-2=https://192.168.1.12:2380,etcd-3=https://192.168.1.13:2380 \\
  --initial-cluster-state new \\
  --initial-cluster-token etcd-poc-token \\
  --cert-file=/etc/etcd/pki/etcd.pem \\
  --key-file=/etc/etcd/pki/etcd-key.pem \\
  --trusted-ca-file=/etc/etcd/pki/ca.pem \\
  --peer-cert-file=/etc/etcd/pki/etcd.pem \\
  --peer-key-file=/etc/etcd/pki/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/etcd/pki/ca.pem \\
  --client-cert-auth \\
  --peer-client-cert-auth
Restart=always
RestartSec=5
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now etcd
systemctl status etcd --no-pager