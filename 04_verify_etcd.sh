#!/bin/bash
set -euo pipefail

etcdctl \
  --endpoints=https://192.168.1.11:2379,https://192.168.1.12:2379,https://192.168.1.13:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem \
  endpoint health

etcdctl \
  --endpoints=https://192.168.1.11:2379,https://192.168.1.12:2379,https://192.168.1.13:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem \
  endpoint status --write-out=table