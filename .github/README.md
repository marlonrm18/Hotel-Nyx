# CI/CD — GitHub Actions (Hotel Nyx)

Dos workflows en `.github/workflows/`:

| Workflow      | Dispara en                              | Qué hace                                                        | ¿Toca AWS? |
|---------------|-----------------------------------------|----------------------------------------------------------------|------------|
| `ci.yml`      | PR y push a `develop`/`main`            | Valida backend, Terraform y Ansible (estático).                | **No**     |
| `deploy.yml`  | `workflow_dispatch` y push a `main`     | Build/push, plan, **apply con aprobación manual**, Ansible, frontend. | Sí (OIDC)  |

Atributos prioritarios: **disponibilidad** y **seguridad**. Región: **us-east-2**.

---

## Flujo completo: de PR a producción

```
feature/* ──PR──► develop ──PR──► main
                                   │
   ci.yml valida cada PR  ─────────┤  (backend + IaC + Ansible, sin AWS)
                                   │
                         push a main / workflow_dispatch
                                   │
                                   ▼
                            deploy.yml
   ┌───────────────────────────────────────────────────────────────┐
   │ 1) build-and-push   (matrix reservas/pagos → ECR, tag = SHA)   │
   │ 2) terraform-plan   (plan + artifact; -var image_tag = SHA)    │
   │            │                                                   │
   │            ▼                                                   │
   │ 3) terraform-apply  ⛔ APROBACIÓN MANUAL (Environment          │
   │            │            "production" + required reviewers)     │
   │            ▼                                                   │
   │ 4) db-orchestrate (Ansible: migrate + seed)                    │
   │ 5) frontend       (config.js ← outputs TF, S3 sync, CF inval.) │
   └───────────────────────────────────────────────────────────────┘
```

**Dependencias entre jobs (`deploy.yml`):**
- `terraform-apply` → `needs: [build-and-push, terraform-plan]` (las imágenes ya
  están en ECR y el plan ya está revisado antes de aplicar).
- `db-orchestrate` y `frontend` → `needs: terraform-apply` (corren en paralelo
  después del apply).

### ¿Dónde está la aprobación manual del apply?
En el job **`terraform-apply`**, mediante el **Environment `production`**. Hay que
crearlo en **Settings → Environments → `production`** y añadir una *protection rule*
con **Required reviewers**. El job se queda **en pausa** hasta que un reviewer lo
aprueba; sin aprobación, **el `apply` no se ejecuta**. El `plan` (paso 2) sí corre
automático, pero solo produce un artifact para revisión — nunca modifica infra.

---

## Secrets y variables de GitHub a crear

> Son **placeholders documentados**: créalos en **Settings → Secrets and variables → Actions**.
> Ningún valor va en los `.yml`.

### Secrets
| Nombre                  | Uso                                                                 |
|-------------------------|---------------------------------------------------------------------|
| `AWS_DEPLOY_ROLE_ARN`   | ARN del rol IAM que GitHub asume vía OIDC (ver abajo). Lo usan todos los jobs de `deploy.yml`. |
| `TF_STATE_BUCKET`       | Nombre del bucket S3 del state remoto (output del bootstrap). Se pasa a `terraform init`. |

### Variables (no sensibles)
| Nombre                | Uso                                                                          |
|-----------------------|------------------------------------------------------------------------------|
| `MP_PUBLIC_KEY`       | Public Key **de TEST** de Mercado Pago (es pública). Se inyecta en `config.js`. |
| `TF_STATE_LOCK_TABLE` | Nombre de la tabla DynamoDB de locks (output del bootstrap). Se pasa a `terraform init`. |

> No se usan **access keys de larga vida**. Si tu organización aún no soporta OIDC,
> la alternativa sería `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` como secrets,
> pero **OIDC es la opción preferida** (credenciales efímeras, sin llaves que rotar).

---

## Rol IAM para OIDC (a crear en AWS)

GitHub Actions se autentica con un **OIDC identity provider** y asume un rol; no hay
llaves estáticas. Hay que crear (una vez, fuera de este pipeline o como módulo de TF):

**1. OIDC provider** (si no existe en la cuenta):
- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

**2. Rol IAM** (`AWS_DEPLOY_ROLE_ARN`) con esta **política de confianza** (restringe
a este repo y, idealmente, a las ramas de despliegue):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main" }
    }
  }]
}
```

**3. Permisos mínimos** del rol (resumido; ajustar a tus ARNs):
- **ECR**: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`,
  `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`,
  `ecr:PutImage` sobre los repos `hotel-nyx/dev/svc-*`.
- **Terraform plan/apply**: como Terraform gestiona toda la arquitectura, el rol
  necesita permisos amplios sobre los servicios que toca (VPC, RDS, ECS, ELB, IAM,
  KMS, Secrets Manager, S3, CloudFront, ACM, Route53, Cognito, SES, API Gateway,
  CloudWatch/SNS). Acótalo a los recursos del proyecto y, si usas backend remoto,
  añade acceso al bucket de state y a la tabla de locks.
- **Ansible (migrate/seed)**: `secretsmanager:GetSecretValue` sobre
  `hotel-nyx/dev/rds/credentials` y `kms:Decrypt` sobre la CMK de RDS.
- **Frontend**: `s3:ListBucket`/`s3:PutObject`/`s3:DeleteObject` sobre el bucket del
  frontend y `cloudfront:CreateInvalidation` sobre la distribución.

---

## Prerrequisitos importantes (honestos, no inventados)

### Backend remoto de Terraform
`terraform-plan` y `terraform-apply` son jobs **separados** que comparten el
**state** vía el backend remoto **S3 + DynamoDB** declarado en `iac/backend.tf`
(config parcial). Antes de usar `deploy.yml` hay que crear ese backend una vez con
el **bootstrap** (`iac/bootstrap/`, ver su README). Los workflows pasan el bucket y
la tabla al `terraform init` por `-backend-config` usando estos valores de GitHub:

| Tipo     | Nombre                | Ejemplo de valor                  |
|----------|-----------------------|-----------------------------------|
| Secret   | `TF_STATE_BUCKET`     | `hotel-nyx-tfstate-<sufijo>`      |
| Variable | `TF_STATE_LOCK_TABLE` | `hotel-nyx-tflocks`               |

`key`/`region`/`encrypt` están fijos en `iac/backend.tf`, así que no se parametrizan.
El `init -backend=false` de `ci.yml` (validación estática) no usa backend y no se ve
afectado.

### Acceso de red al RDS privado (jobs de migración/seed)
El RDS está en **subnets privadas** y **no** se expone a internet. Un runner
**GitHub-hosted estándar no tiene acceso a la VPC**, así que `db-orchestrate`
fallará tal cual. Opciones (elegir una y ajustar `runs-on`):
- **self-hosted runner** desplegado **dentro de la VPC**,
- **SSM port-forward** a través de un bastión hacia el endpoint del RDS,
- ejecutar ese paso desde **CodeBuild** en la VPC.

**No** se abre el RDS a internet. Esto está anotado también dentro de `deploy.yml`.

### `config.js` del frontend
Los placeholders `REEMPLAZAR_*` de `app/frontend/js/config.js` se rellenan en el job
`frontend` con **outputs reales de Terraform** (`api_custom_domain_url`,
`cognito_hosted_ui_url`, `cognito_user_pool_id`, `cognito_client_id`) y con
`vars.MP_PUBLIC_KEY`. La sustitución **depende de que esos outputs existan** tras el
apply; no se hardcodean valores en el repo.

---

## Nota sobre el playbook Ansible `04_deploy`

`db-orchestrate` corre **solo** `--tags migrate,seed`. **No** ejecuta el playbook
`04_deploy` (build/push + force-new-deployment) porque:
- el **build/push ya lo hace** el job `build-and-push` (con OIDC y tag = SHA), y
- el **ECR es IMMUTABLE**: reintentar el push del mismo tag fallaría.

El **rollout de ECS** se dispara solo en el `terraform apply`: al cablear el tag de
imagen (SHA) en las task definitions, ECS registra una revisión nueva y hace un
**rolling deployment sin downtime**. El playbook `04_deploy` sigue disponible para
uso **manual/local** fuera de CI.
