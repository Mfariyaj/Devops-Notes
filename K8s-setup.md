# EKS WordPress Stateful Application with EBS & ALB Ingress

This document explains **step-by-step** how to deploy a **production-grade WordPress application on Amazon EKS**, using:

* Kubernetes **Deployment** and **StatefulSet**
* **AWS EBS CSI Driver** for persistent storage
* **MySQL StatefulSet** with PVC
* **AWS Load Balancer Controller (ALB Ingress)**
* **IRSA (IAM Roles for Service Accounts)**

Each step explains **WHAT we do** and **WHY we do it**.

---

## 1. Architecture Overview

```
User
 ↓
Application Load Balancer (ALB)
 ↓
Ingress (ALB Ingress)
 ↓
ClusterIP Service
 ↓
WordPress Pod (Deployment)
 ↓
MySQL Pod (StatefulSet)
 ↓
PVC → StorageClass → EBS Volume
```

---

## 2. Why These Kubernetes Objects Are Used

| Component        | Why It Is Used                          |
| ---------------- | --------------------------------------- |
| Deployment       | WordPress is stateless at compute level |
| StatefulSet      | MySQL needs stable identity & storage   |
| PVC              | Data persistence                        |
| StorageClass     | Dynamic EBS provisioning                |
| Secret           | Secure DB credentials                   |
| Headless Service | Stable DNS for MySQL                    |
| Ingress          | Layer-7 routing                         |
| ALB Controller   | AWS-managed load balancer               |

---

## 3. Install AWS EBS CSI Driver (Storage)

### Why

* EKS does not support in-tree EBS
* CSI driver allows **dynamic EBS provisioning**

### 3.1 Associate OIDC Provider (Required for IRSA)

```bash
eksctl utils associate-iam-oidc-provider \
--cluster my-eks-cluster \
--region ap-south-1 \
--approve
```

---

### 3.2 Install EBS CSI as EKS Add-on (Recommended)

```bash
aws eks create-addon \
--cluster-name my-eks-cluster \
--addon-name aws-ebs-csi-driver \
--region ap-south-1
```

Verify:

```bash
kubectl get pods -n kube-system | grep ebs
```

---

## 4. Create StorageClass (gp3)

### Why

* Controls volume type, AZ binding, expansion

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  fsType: ext4
```

```bash
kubectl apply -f storageclass-gp3.yaml
```

---

## 5. Create MySQL Headless Service

### Why

* StatefulSet requires stable DNS
* Prevents load-balancing across DB pods

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
```

---

## 6. Create MySQL Secret

### Why

* Credentials must not be hardcoded

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  mysql-root-password: bXlzcWwxMjM=
```

---

## 7. MySQL StatefulSet with EBS PVC

### Why StatefulSet

* Stable pod name
* Persistent storage
* Ordered restart

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_DATABASE
          value: wordpress
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: ebs-gp3
      resources:
        requests:
          storage: 10Gi
```

---

## 8. WordPress Deployment

### Why Deployment

* WordPress frontend is stateless

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:apache
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql-0.mysql
        - name: WORDPRESS_DB_NAME
          value: wordpress
        - name: WORDPRESS_DB_USER
          value: root
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
```

---

## 9. WordPress ClusterIP Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress-svc
spec:
  type: ClusterIP
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
```

---

## 10. Install AWS Load Balancer Controller

### Why

* Native ALB support
* Layer 7 routing
* AWS-managed scaling

### 10.1 Create ServiceAccount

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
```

### 10.2 Annotate with IAM Role

```bash
kubectl annotate serviceaccount aws-load-balancer-controller \
-n kube-system \
eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKSLoadBalancerControllerRole
```

### 10.3 Install using Helm

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
-n kube-system \
--set clusterName=my-eks-cluster \
--set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller \
--set region=ap-south-1 \
--set vpcId=<VPC_ID>
```

---

## 11. ALB Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress-svc
            port:
              number: 80
```

---

## 12. Verification

```bash
kubectl get ingress
kubectl get pvc
kubectl get pv
kubectl get pods
```

Access:

```
http://<ALB-DNS-NAME>
```

---

## 13. Persistence Test

1. Create WordPress post
2. Delete MySQL pod
3. Refresh page

✅ Data persists

---

## 14. Interview One-Liner

"I deployed WordPress on EKS using MySQL StatefulSet backed by EBS CSI volumes and exposed it via ALB Ingress using AWS Load Balancer Controller with IRSA for secure access."

