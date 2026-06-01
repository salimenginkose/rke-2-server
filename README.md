# RKE2 + External etcd HA Cluster — Full Setup Guide

Sources:

- https://docs.rke2.io/install/quickstart
- https://etcd.io/docs/v3.5/install/
- https://medium.com/devopsturkiye/etcd-cluster-kurulumu-ve-backup-restore-i%CC%87%C5%9Flemleri-009f4696be1f

## What This Project Does

3 etcd nodes form a high availability cluster. 1 RKE2 node connects to that etcd cluster instead of using its own built-in etcd. When any single etcd node goes down, Raft quorum holds (2/3 majority) and Kubernetes keeps running without interruption.

---

## Infrastructure

| Machine | Role | IP |
|---------|------|----|
| etcd-1 | etcd cluster node | 192.168.1.11 |
| etcd-2 | etcd cluster node | 192.168.1.12 |
| etcd-3 | etcd cluster node | 192.168.1.13 |
| rke2-node | Kubernetes (RKE2) | 192.168.1.20 |

**Minimum specs per VM:** 2 CPU, 2GB RAM, Ubuntu 22.04+

**Ports required:**
- 2379 — etcd client (between all nodes)
- 2380 — etcd peer (between etcd nodes)
- 6443 — RKE2 API (inbound on rke2-node)
- 22 — SSH (all nodes)

---

## Step 0 — Prepare All Nodes (run on every VM)

### Set root password
```bash
sudo passwd root
```

### Enable SSH root login and password authentication ( On all VM's)
```
sudo bash
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh
```

### Set up passwordless SSH from your main machine (run once on the machine you work from)
```
sudo bash
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa ( Run on every node first)
ssh-copy-id root@192.168.1.11
ssh-copy-id root@192.168.1.12
ssh-copy-id root@192.168.1.13
ssh-copy-id root@192.168.1.20
```

## Step 0.5(Optional) 
```
If you send it from windows or copy paste use this command after sending scripts. Which going to fix script lines.

sed -i 's/\r//' *.sh 
```
---

## Step 1 — Install etcd (etcd-1, etcd-2, etcd-3)

Run `01_install_etcd.sh` on all 3 etcd nodes:

```bash
sudo bash 01_install_etcd.sh
```

This downloads etcd v3.5.13 binary and places it in `/usr/local/bin`.

Verify:
```bash
etcd --version
etcdctl version
```

---

## Step 2 — Generate TLS Certificates (Should be in order of RKE-2->ETCD-1->2->3)

Run `02_generate_certs.sh`:

```bash
sudo bash 02_generate_certs.sh
```

Certificates are placed at:
- etcd nodes: `/etc/etcd/pki/`
- rke2-node: `/etc/rancher/rke2/`

---

## Step 3 — Configure and Start etcd (ETCD-2-3->1)

Run `03_configure_etcd.sh` on each etcd node, passing the node number as argument:

```bash
# On etcd-1
sudo bash 03_configure_etcd.sh 1

# On etcd-2
sudo bash 03_configure_etcd.sh 2

# On etcd-3
sudo bash 03_configure_etcd.sh 3
```

This creates a systemd service for etcd on each node with the correct name, IP, and cluster peer addresses. The service is enabled so it starts automatically on reboot.

> **Important:** etcd requires all 3 nodes to start roughly at the same time on first boot. Start all 3 within a few seconds of each other. If one times out, stop etcd on all 3, delete `/var/lib/etcd`, and start all 3 again simultaneously.

```bash
# If you need to restart fresh
systemctl stop etcd
rm -rf /var/lib/etcd
systemctl start etcd
```

---

## Step 4 — Verify etcd Cluster Health

Run `04_verify_etcd.sh` from any etcd node:

```bash
sudo bash 04_verify_etcd.sh
```

Expected output:
```
https://192.168.1.11:2379 is healthy
https://192.168.1.12:2379 is healthy
https://192.168.1.13:2379 is healthy
```

Do not proceed to RKE2 installation until all 3 show healthy.

---

## Step 5 — Install and Configure RKE2 (rke2-node)

Then on rke2-node:
```bash
sudo bash 05_install_rke2.sh

After waiting it should show 

NAME    STATUS   ROLES           AGE    VERSION
rke-2   Ready    control-plane   2m2s   v1.35.5+rke2r2

```
RKE2 should be installed in like 5-10 mins. Watch it:
```bash
journalctl -fu rke2-server
```

### Fix kubectl permissions (run once after RKE2 is up)

```bash
# Fix permissions permanently on every reboot
sudo bash -c 'cat > /etc/systemd/system/rke2-kubeconfig-fix.service <<EOF
[Unit]
Description=Fix rke2 kubeconfig permissions
After=rke2-server.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 644 /etc/rancher/rke2/rke2.yaml
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable rke2-kubeconfig-fix.service

# Add kubectl to PATH
echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
source ~/.bashrc
```

Verify node is ready:
```bash
kubectl get nodes
```

Expected:
```
NAME      STATUS   ROLES                       AGE   VERSION
rke-2     Ready    control-plane,etcd,master   5m    v1.35.5+rke2r1
```

---

## Step 6 — Deploy Sample nginx App

Run `06_deploy_app.sh` on rke2-node:

```bash
sudo bash 06_deploy_app.sh
```

This creates an nginx deployment and exposes it via NodePort. Note the port number from the output and access it at:
```
http://192.168.1.20:<nodeport>
```

---

## Step 7 — Deploy Your HTML Game

Place your `game.html` file on rke2-node, then:

```bash
# Create configmap from your html file
kubectl create configmap my-game --from-file=index.html=game.html

# Deploy nginx to serve it
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-game
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-game
  template:
    metadata:
      labels:
        app: my-game
    spec:
      volumes:
      - name: game
        configMap:
          name: my-game
      containers:
      - name: my-game
        image: nginx:alpine
        volumeMounts:
        - name: game
          mountPath: /usr/share/nginx/html
          readOnly: true
EOF

# Expose it
kubectl expose deployment my-game --port=80 --type=NodePort
kubectl get svc my-game
```

Access your game at:
```
http://192.168.1.20:<nodeport>
```
 80:31981
To update game.html later:
```bash
kubectl create configmap my-game --from-file=index.html=game.html --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment my-game
```

---

## Step 8 — Failure Test

### Test 1 — Single etcd node failure (expected: everything keeps working)

```bash
# Shut down etcd-3
ssh root@192.168.1.13 "shutdown -h now"

# Check cluster still healthy from etcd-1
etcdctl \
  --endpoints=https://192.168.1.11:2379,https://192.168.1.12:2379,https://192.168.1.13:2379 \
  --cacert=/etc/etcd/pki/ca.pem \
  --cert=/etc/etcd/pki/etcd.pem \
  --key=/etc/etcd/pki/etcd-key.pem \
  endpoint health

# Verify Kubernetes still works on rke2-node
kubectl get pods,nodes
curl http://192.168.1.20:<nodeport>

# Bring etcd-3 back
ssh root@192.168.1.13 "systemctl start etcd"
```

Expected: 2 nodes healthy, app still reachable, kubectl works normally.

### Test 2 — All etcd nodes down (expected: kubectl freezes, app still runs)

```bash
# Shut down all etcd nodes
ssh root@192.168.1.11 "shutdown -h now"
ssh root@192.168.1.12 "shutdown -h now"
ssh root@192.168.1.13 "shutdown -h now"

# kubectl will freeze — no quorum
kubectl get pods   # hangs

# App still reachable because kubelet is independent
curl http://192.168.1.20:<nodeport>

# Boot etcd nodes back up — everything restores automatically
```

---

## Correct Boot Order

Always start etcd nodes before rke2-node:

```
1. Boot etcd-1, etcd-2, etcd-3
2. Wait ~30 seconds
3. Boot rke2-node
4. Wait ~2 minutes
5. kubectl get pods — everything running
```

If rke2-node boots before etcd is ready, RKE2 fails to connect. Fix:
```bash
sudo systemctl restart rke2-server
```

---

## File Structure

```
project/
├── scripts/
│   ├── 01_install_etcd.sh
│   ├── 02_generate_certs.sh
│   ├── 03_configure_etcd.sh
│   ├── 04_verify_etcd.sh
│   ├── 05_install_rke2.sh
│   ├── 06_deploy_app.sh
│   └── 07_test_failure.sh
├── game.html
├── .gitignore
└── README.md
```




