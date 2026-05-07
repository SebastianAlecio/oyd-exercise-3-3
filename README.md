# oyd-exercise-3-3 — Módulo EKS

Contraparte EKS de las demos en clase de *Optimizaciones y Desempeño — Cloud Deployment Automation* (sesión 3, 2026-05-07). Provisiona un cluster Amazon EKS mínimo con el módulo Terraform de la comunidad, despliega una API Python `/health` + `/echo` sobre nodos arm64 y la expone vía un NLB.

## Contrato de la aplicación

| Método | Ruta     | Respuesta                                                            |
|--------|----------|----------------------------------------------------------------------|
| GET    | `/health`| `{"status":"ok","compute":"eks"}`                                    |
| POST   | `/echo`  | el JSON del body con `"compute":"eks"` agregado                      |

Código: [`app/app.py`](app/app.py) — `http.server` raw, sin framework. Imagen: `atreality/ex33-health-api:1.0.0` (arm64, Docker Hub).

## Estructura del repositorio

```
.
├── app/                       # servidor HTTP en Python + Dockerfile
├── infra/
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf                # data sources + llamada al módulo
│   ├── outputs.tf
│   ├── envs/dev/dev.tfvars    # valores para el entorno dev
│   └── modules/eks_cluster/   # wrapper reutilizable de terraform-aws-modules/eks/aws ~> 20.0
├── k8s/                       # namespace, configmap, deployment, service
└── evidence/                  # screenshots y output de los curl
```

## Prerrequisitos

- AWS CLI v2 con credenciales que puedan crear EKS, IAM y EC2
- Terraform CLI ≥ 1.8
- `kubectl`
- Docker Desktop corriendo (con `buildx`)
- Cuenta de Docker Hub (u otro registry público); login hecho con `docker login`

## Cómo ejecutar

### 1. Provisionar el cluster

```bash
cd infra/
terraform init
terraform plan  -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars     # ~12-18 min
```

### 2. Actualizar kubeconfig y verificar

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name $(terraform -chdir=infra output -raw cluster_name)

kubectl get nodes -o wide
```

Al menos un nodo debe aparecer en `STATUS=Ready` antes de continuar.

### 3. Construir y publicar la imagen (arm64 para que coincida con los nodos `t4g.small`)

```bash
docker login

# En Apple Silicon esto produce la imagen arm64 correcta.
# En hardware Intel hay que correr antes `docker buildx create --use`.
docker buildx build --platform linux/arm64 \
  -t atreality/ex33-health-api:1.0.0 \
  --push app/
```

### 4. Desplegar y verificar la aplicación

```bash
kubectl apply -f k8s/
kubectl get pods -n ex33 -w        # esperar 2/2 Running
kubectl get svc  -n ex33           # esperar a que el EXTERNAL-IP se llene (~2-3 min)

NLB=$(kubectl get svc health-api -n ex33 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://${NLB}/health
# {"status":"ok","compute":"eks"}

curl -X POST http://${NLB}/echo \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
# {"compute":"eks","message":"hello"}
```

### 5. Destruir todo (para evitar costos)

Hay que borrar los Services tipo LoadBalancer **antes** de `terraform destroy`. Terraform no es dueño del NLB que creó el Service controller — si lo dejas activo, el teardown del VPC se puede colgar.

```bash
kubectl delete -f k8s/
cd infra/
terraform destroy -var-file=envs/dev/dev.tfvars
```

## Módulo — tres ajustes que no son opcionales

El módulo en `infra/modules/eks_cluster/main.tf` define explícitamente tres parámetros:

| Parámetro | Por qué |
|---|---|
| `enable_cluster_creator_admin_permissions = true` | Sin esto, la identidad IAM que corrió `apply` no puede usar `kubectl` (cada llamada devuelve `403`). |
| `cluster_upgrade_policy = { support_type = "STANDARD" }` | Fija el cluster a la ventana de soporte estándar para que no arranque automáticamente la facturación de soporte extendido de EKS. |
| `ami_type = "AL2023_ARM_64_STANDARD"` (en el node group) | Requerido para instancias `t4g`. Con la AMI x86_64 por defecto el binario de kubelet falla con `exec format error`. |

## Evidencia

### `kubectl get nodes -o wide`

![EKS nodes Ready](evidence/eks-nodes.png)

### Pruebas de los endpoints

Output crudo en [`evidence/curl-output.txt`](evidence/curl-output.txt):

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
