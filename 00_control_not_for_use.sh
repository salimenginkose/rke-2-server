#!/bin/bash

########################################
# ON etcd-3: kill it
########################################
# shutdown -h now


########################################
# ON etcd-1 or etcd-2: check cluster
########################################
etcdctl \
  --endpoints=https://192.168.1.11:2379,https://192.168.1.12:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem \
  endpoint health
# Expect: 2 healthy, etcd-3 unreachable


########################################
# ON rke2-node: verify Kubernetes still works
########################################
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
/var/lib/rancher/rke2/bin/kubectl get nodes
/var/lib/rancher/rke2/bin/kubectl get pods
# Both should return normally


########################################
# ON etcd-3: bring it back (after boot)
########################################
# systemctl start etcd
