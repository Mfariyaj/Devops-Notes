# Monitoring Stack on Amazon EKS

## Prometheus + Grafana with ALB Ingress & Route53 (Host-Based Routing)

---

## Overview

This document describes how to install **Prometheus and Grafana** on an **Amazon EKS** cluster using **kube-prometheus-stack**, and expose them using **AWS Application Load Balancer (ALB)** with **host-based routing** via **Route53**, while sharing **a single ALB** across applications.

---

## Final Architecture

```
                    ┌───────────────────────────┐
                    │        Route53 DNS         │
                    │                           │
                    │  wordpress.test.com       │
                    │  grafana.test.com         │
                    │  prometheus.test.com      │
                    └─────────────┬─────────────┘
                                  │
                        ┌─────────▼─────────┐
                        │   AWS ALB (ONE)   │
                        │  Internet Facing │
                        └─────────┬─────────┘
              ┌───────────────────┼────────────────────┐
              │                   │                    │
      ┌───────▼───────┐   ┌───────▼────────┐   ┌───────▼────────┐
      │ WordPress     │   │ Grafana         │   │ Prometheus     │
      │ Service       │   │ Service         │   │ Service        │
      │ (ClusterIP)   │   │ (ClusterIP)     │   │ (ClusterIP)    │
      └───────┬───────┘   └───────┬────────┘   └───────┬────────┘
              │                   │                    │
        WordPress Pod       Grafana Pod         Prometheus Pod
```

---

## Prerequisites

* Running Amazon EKS cluster
* `kubectl` configured
* `helm` installed
* AWS Load Balancer Controller installed
* Route53 hosted zone (or `/etc/hosts` for testing)

---

## Step 1: Add Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Step 2: Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

---

## Step 3: Install Prometheus & Grafana

This installs:

* Prometheus
* Alertmanager
* Grafana
* Node Exporter
* kube-state-metrics

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring
```

Verify:

```bash
kubectl get pods -n monitoring
```

---

## Step 4: Why Host-Based Routing

### Problems with path-based routing

* Grafana and Prometheus expect `/`
* Static assets break on sub-paths
* Extra configuration required

### Benefits of host-based routing

* Clean URLs
* No application-level hacks
* One ALB
* Production best practice

---

## Step 5: Host-Based Ingress Configuration (Single ALB)

All ingress resources share the same ALB using:

```
alb.ingress.kubernetes.io/group.name: monitoring-alb
```

---

### WordPress Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/group.name: monitoring-alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: wordpress.test.com
    http:
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

### Grafana Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/group.name: monitoring-alb
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: grafana.test.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 80
```

---

### Prometheus Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/group.name: monitoring-alb
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: prometheus.test.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-kube-prometheus-stack-prometheus
            port:
              number: 9090
```

Apply:

```bash
kubectl apply -f wordpress-ingress.yaml
kubectl apply -f grafana-ingress.yaml
kubectl apply -f prometheus-ingress.yaml
```

---

## Step 6: Verify Single ALB

```bash
kubectl get ingress -A
```

All ingresses should show the **same ALB DNS**.

---

## Step 7: Route53 Configuration

Create DNS records pointing to the ALB DNS:

| Record              | Target  |
| ------------------- | ------- |
| wordpress.test.com  | ALB DNS |
| grafana.test.com    | ALB DNS |
| prometheus.test.com | ALB DNS |

For local testing:

```bash
sudo nano /etc/hosts
```

```
<ALB-IP> wordpress.test.com
<ALB-IP> grafana.test.com
<ALB-IP> prometheus.test.com
```

---

## Step 8: Security Best Practices

* Use **internal ALB** for Prometheus
* Enable **HTTPS with ACM**
* Restrict access via CIDR
* Enable authentication for Grafana
* Avoid public Prometheus exposure

---

## Step 9: Grafana Login

```bash
kubectl get secret prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-user}" | base64 -d

kubectl get secret prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

---

## Recommended Grafana Dashboards

| Purpose            | Dashboard ID |
| ------------------ | ------------ |
| Kubernetes Cluster | 6417         |
| Nodes              | 1860         |
| Pods               | 6336         |
| Node Exporter      | 11074        |
| API Server         | 15761        |

---

## Interview-Ready Summary

> I deployed Prometheus and Grafana on EKS using kube-prometheus-stack and exposed them through a single ALB using host-based routing via Route53. This avoided sub-path issues, reduced cost, and followed production best practices.

---

## Final URLs

```
https://wordpress.test.com
https://grafana.test.com
https://prometheus.test.com
```

---

## Optional Enhancements

* HTTPS (ACM + ALB)
* Alertmanager to Slack / Email
* Prometheus EBS retention
* Grafana OAuth / IAM
* Convert to PDF / GitHub README

