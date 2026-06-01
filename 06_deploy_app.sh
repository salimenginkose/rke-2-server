#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
KUBECTL=/var/lib/rancher/rke2/bin/kubectl

$KUBECTL create deployment nginx-demo --image=nginx:stable --replicas=1
$KUBECTL expose deployment nginx-demo --port=80 --type=NodePort
$KUBECTL get pods,svc