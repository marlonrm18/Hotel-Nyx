# Hotel Nyx — Infraestructura AWS con Terraform

Sistema de reservas de hotel desplegado en AWS. Atributos de calidad prioritarios: **Disponibilidad** y **Seguridad**.

| Atributo         | Decisión arquitectónica clave                                     |
|------------------|-------------------------------------------------------------------|
| Disponibilidad   | Multi-AZ en RDS, NAT GW por AZ, ECS min 2 tareas, ALB cross-AZ  |
| Seguridad        | VPC privada, SGs de mínimo privilegio, KMS, Secrets Manager, TLS |

## Región principal
`us-east-2` (Ohio) — provider alias `us-east-1` sólo para certificados ACM de CloudFront.

## Requisitos
- Terraform `>= 1.9`
- AWS CLI configurado (`aws configure` o variables de entorno)
- Permisos IAM para los servicios involucrados
- Un par de claves KMS pre-existente o se crea dentro del módulo `database`

## Estructura del repositorio

```
Hotel-Nyx/
├── environments/
│   └── dev/              ← punto de entrada de Terraform
│       ├── versions.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── main.tf       ← llama a los módulos
│       ├── outputs.tf
│       └── dev.tfvars.example
└── modules/
    ├── networking/
    ├── security-groups/
    ├── ecr/
    ├── alb/
    ├── ecs/
    ├── database/
    ├── cognito/
    ├── api-gateway/
    ├── frontend/
    ├── dns/
    ├── messaging/
    └── monitoring/
```

## Uso rápido

```bash
cd environments/dev

# 1. Copiar y editar variables
cp dev.tfvars.example dev.tfvars   # dev.tfvars está en .gitignore

# 2. Inicializar
terraform init

# 3. Revisar plan
terraform plan -var-file="dev.tfvars"

# 4. Aplicar (sólo tras revisión manual)
terraform apply -var-file="dev.tfvars"
```

## Módulos

| Módulo           | Descripción                                                        |
|------------------|--------------------------------------------------------------------|
| `networking`     | VPC /16, 2 AZs, subnets púb/priv, IGW, NAT GW por AZ             |
| `security-groups`| SG-ALB, SG-ECS, SG-RDS con mínimo privilegio                      |
| `ecr`            | Repositorios svc-reservas y svc-pagos, scan on push               |
| `alb`            | ALB HTTPS (443), redirect 80→443, target groups IP para Fargate   |
| `ecs`            | Cluster Fargate, servicios reservas y pagos, auto-scaling         |
| `database`       | RDS PostgreSQL Multi-AZ, KMS, Secrets Manager, Performance Insights|
| `cognito`        | User Pool, app client, scopes hotel-api                           |
| `api-gateway`    | API Gateway Regional, authorizer Cognito JWT, dominio custom      |
| `frontend`       | S3 privado + CloudFront OAC, TLS 1.2+, cert ACM us-east-1        |
| `dns`            | Route 53: raíz/www → CloudFront, api.hotelnyx.com → API GW       |
| `messaging`      | SES domain identity DKIM + VPC Interface Endpoint (PrivateLink)  |
| `monitoring`     | CloudWatch logs/alarms/dashboard, SNS topic                       |

## Convenciones de etiquetas

Todos los recursos reciben `default_tags` vía el provider:

```
Project     = "hotel-nyx"
Environment = <dev|staging|prod>
ManagedBy   = "terraform"
```

## Migraciones de base de datos — un solo dueño

Solo **svc-reservas** aplica migraciones (`prisma migrate deploy`) contra la RDS.
Es el único dueño del esquema, incluida la *exclusion constraint* anti-doble-reserva
(`app/reservas/prisma/migrations/20260618090106_init/migration.sql`).

**svc-pagos NO migra**: únicamente se conecta a la BD ya migrada. No tiene script
ni comando de migración y su arranque (`CMD ["node", "src/index.js"]`) nunca dispara
una migración. Su `schema.prisma` existe solo para `prisma generate` (cliente tipado).

Esto evita migraciones concurrentes desde dos servicios (race conditions / locks)
y mantiene un único punto de verdad del esquema.

## Seguridad — checklist rápido

- [ ] Ningún secreto hardcodeado (`random_password` + Secrets Manager)
- [ ] Cifrado KMS en RDS, S3 y CloudWatch Logs
- [ ] TLS mínimo 1.2 en CloudFront y ALB
- [ ] SGs sin regla `0.0.0.0/0` entrante excepto ALB 443
- [ ] Tareas ECS en subnets privadas
- [ ] SES via PrivateLink (sin salir por NAT)
