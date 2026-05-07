# oyd-exercise-3-3 — EKS Module

EKS-track counterpart to the in-class demos for *Optimizaciones y Desempeño — Cloud Deployment Automation* (session 3, 2026-05-07). Provisions a minimal Amazon EKS cluster with the community Terraform module, deploys a Python `/health` + `/echo` API to arm64 nodes, and exposes it through an NLB.

## Application contract

| Method | Path     | Response                                                            |
|--------|----------|---------------------------------------------------------------------|
| GET    | `/health`| `{"status":"ok","compute":"eks"}`                                   |
| POST   | `/echo`  | request body JSON with `"compute":"eks"` appended                   |

Source: [`app/app.py`](app/app.py) — raw `http.server`, no framework. Image: `atreality/ex33-health-api:1.0.0` (arm64, Docker Hub).

## Repository layout

```
.
├── app/                       # Python HTTP server + Dockerfile
├── infra/
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf                # data sources + module call
│   ├── outputs.tf
│   ├── envs/dev/dev.tfvars    # dev environment values
│   └── modules/eks_cluster/   # reusable wrapper of terraform-aws-modules/eks/aws ~> 20.0
├── k8s/                       # namespace, configmap, deployment, service
└── evidence/                  # screenshots and curl output
```

## Prerequisites

- AWS CLI v2 with credentials that can create EKS, IAM, and EC2 resources
- Terraform CLI ≥ 1.8
- `kubectl`
- Docker Desktop running (with `buildx`)
- A Docker Hub (or other public registry) account; logged in via `docker login`

## How to run

### 1. Provision the cluster

```bash
cd infra/
terraform init
terraform plan  -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars     # ~12-18 min
```

### 2. Update kubeconfig and verify

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name $(terraform -chdir=infra output -raw cluster_name)

kubectl get nodes -o wide
```

At least one node must show `STATUS=Ready` before continuing.

### 3. Build and push the container image (arm64 to match `t4g.small` nodes)

```bash
docker login

# On Apple Silicon, this produces the correct arm64 image.
# On Intel hardware, run `docker buildx create --use` first.
docker buildx build --platform linux/arm64 \
  -t atreality/ex33-health-api:1.0.0 \
  --push app/
```

### 4. Deploy and verify the application

```bash
kubectl apply -f k8s/
kubectl get pods -n ex33 -w        # wait until 2/2 Running
kubectl get svc  -n ex33           # wait until EXTERNAL-IP is populated (~2-3 min)

NLB=$(kubectl get svc health-api -n ex33 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://${NLB}/health
# {"status":"ok","compute":"eks"}

curl -X POST http://${NLB}/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
# {"compute":"eks","message":"hello"}
```

### 5. Tear down (avoid ongoing charges)

Delete Kubernetes LoadBalancer Services *before* `terraform destroy`. Terraform does not own the NLB created by the Service controller — leaving it in place can hang the VPC teardown.

```bash
kubectl delete -f k8s/
cd infra/
terraform destroy -var-file=envs/dev/dev.tfvars
```

## Module — three settings that are not optional

The module at `infra/modules/eks_cluster/main.tf` makes three settings explicit:

| Setting | Why |
|---|---|
| `enable_cluster_creator_admin_permissions = true` | Without it, the IAM identity that ran `apply` cannot use `kubectl` (every call returns `403`). |
| `cluster_upgrade_policy = { support_type = "STANDARD" }` | Pins the cluster to the standard support window so EKS extended-support billing does not start automatically. |
| `ami_type = "AL2023_ARM_64_STANDARD"` (in the node group) | Required for `t4g` instance types. With the default x86_64 AMI the kubelet binary fails with `exec format error`. |

## Evidence

### `kubectl get nodes -o wide`

![EKS nodes Ready](evidence/eks-nodes.png)

### Endpoint smoke tests

Raw output stored in [`evidence/curl-output.txt`](evidence/curl-output.txt):

```
=== GET /health ===
HTTP/1.0 200 OK
Server: BaseHTTP/0.6 Python/3.12.13
Content-Type: application/json

{"status": "ok", "compute": "eks"}

=== POST /echo ===
HTTP/1.0 200 OK
Server: BaseHTTP/0.6 Python/3.12.13
Content-Type: application/json

{"message": "hello", "compute": "eks"}
```
