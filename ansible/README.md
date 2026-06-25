# Ansible — Orquestación de configuración (Hotel Nyx)

Ansible aquí actúa como **orquestador de configuración lógica post-aprovisionamiento**
(**Modo A**: sin SSH, sin hosts remotos; corre en `localhost`/CI usando módulos de
AWS y comandos). **Terraform** (`iac/`) ya aprovisiona toda la infraestructura
(VPC, RDS, ECS, ECR, Secrets Manager, etc.). Ansible **no recrea recursos**: solo
hace lo que Terraform no hace —migraciones de BD, seed, inyección del valor real
del secret de Mercado Pago y el rollout de los servicios ECS—.

Atributos prioritarios del proyecto: **disponibilidad** y **seguridad**.

> ⚠️ **Ejecución desde WSL2 (no PowerShell nativo).** Ansible no soporta correr el
> nodo de control sobre Windows nativo (falla con `os.get_blocking`). Todos los
> comandos de este README se ejecutan dentro de **WSL2** (Ubuntu o similar), con
> Python, Docker y AWS CLI disponibles en esa shell. Desde WSL puedes acceder al
> repo en `/mnt/c/Users/Marlon/Downloads/Hotel-Nyx/ansible`.

## Estructura

```
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.ini            # solo localhost (connection=local)
├── group_vars/
│   └── all.yml              # vars NO sensibles (región, nombres de recursos, seed)
├── playbooks/
│   ├── site.yml             # maestro: 01 → 02 → 03 → 04 (con tags)
│   ├── 01_db_migrate.yml    # migraciones Prisma de RESERVAS contra el RDS
│   ├── 02_db_seed.yml       # seed de habitaciones (idempotente)
│   ├── 03_secrets.yml       # put-secret-value del secret de Mercado Pago
│   └── 04_deploy.yml        # build/push a ECR + force-new-deployment ECS
└── README.md
```

## Requisitos

### Herramientas
- **Ansible** (core ≥ 2.15).
- **Colecciones Ansible**:
  ```bash
  ansible-galaxy collection install amazon.aws community.aws community.postgresql
  ```
- **Python**: `boto3` y `botocore` (para los módulos/lookups de AWS) y
  `psycopg2-binary` (para `community.postgresql`):
  ```bash
  pip install boto3 botocore psycopg2-binary
  ```
- **Node.js + npm** y dependencias de `app/reservas` instaladas (`npm ci`) para
  poder correr `npx prisma migrate deploy` (playbook 01).
- **Docker** y **AWS CLI v2** para el playbook 04 (build/push y `update-service`).

### Credenciales AWS
Las credenciales se toman **del entorno** (perfil o variables) — **NUNCA** se
ponen en los playbooks:
```bash
export AWS_PROFILE=hotel-nyx-dev
export AWS_REGION=us-east-2
# o AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
```

### Acceso de red al RDS (playbooks 01 y 02)
El RDS está en **subnets privadas**: **no** hay acceso público. Los playbooks que
tocan la BD (`01_db_migrate`, `02_db_seed`) deben ejecutarse desde un punto **con
acceso a la VPC**, por ejemplo:
- el **runner de CI dentro de la red** (subnet privada/con ruta al RDS), o
- un **bastión** / **SSM port-forward** hacia el endpoint del RDS.

No se inventa acceso público al RDS. Los playbooks 03 (Secrets Manager) y 04
(ECR/ECS) solo usan APIs públicas de AWS y no requieren estar dentro de la VPC.

## Orden de ejecución

Todo de una vez (maestro):
```bash
cd ansible
ansible-playbook playbooks/site.yml
```

O por etapas (tags):
```bash
ansible-playbook playbooks/site.yml --tags migrate   # 01
ansible-playbook playbooks/site.yml --tags seed      # 02
ansible-playbook playbooks/site.yml --tags secrets   # 03
ansible-playbook playbooks/site.yml --tags deploy    # 04
```

| Paso | Playbook            | Qué hace                                                                 |
|------|---------------------|--------------------------------------------------------------------------|
| 01   | `01_db_migrate.yml` | `prisma migrate deploy` del servicio **reservas** contra el RDS.         |
| 02   | `02_db_seed.yml`    | Inserta las habitaciones iniciales (idempotente).                        |
| 03   | `03_secrets.yml`    | Inyecta el valor real del secret `hotel-nyx/dev/mercadopago`.            |
| 04   | `04_deploy.yml`     | Build + push a ECR (aws-cli) y `force_new_deployment` vía `community.aws.ecs_service`. |

> **Solo `reservas` aplica migraciones** (es el dueño del schema). `pagos` comparte
> la misma BD pero no migra.

### El secret de Mercado Pago (playbook 03)
Por seguridad, el `access_token` y el `webhook_secret` **no** se versionan. Dos vías:

- **Prompt interactivo** (por defecto):
  ```bash
  ansible-playbook playbooks/site.yml --tags secrets
  ```
- **ansible-vault** (no interactivo, para CI). Crea un archivo cifrado:
  ```bash
  ansible-vault create secret.vault.yml
  # contenido:
  # mp_access_token: "TEST-xxxxxxxx"
  # mp_webhook_secret: "yyyyyyyy"
  ansible-playbook playbooks/site.yml --tags secrets -e @secret.vault.yml --ask-vault-pass
  ```
  Si `mp_access_token`/`mp_webhook_secret` ya vienen definidas, el prompt se omite.

## Cómo cada playbook respeta seguridad e idempotencia

**Seguridad (sin secretos en texto plano):**
- Ningún secreto está escrito en los playbooks ni en `group_vars/all.yml`.
- Las credenciales de BD (01, 02) se **leen en runtime** del secret de RDS en
  Secrets Manager (`lookup('amazon.aws.aws_secret', ...)`); la password nunca se
  versiona y la conexión fuerza `sslmode=require`.
- El secret de Mercado Pago (03) se pide por **prompt** o se pasa por
  **ansible-vault**; nunca hardcodeado.
- El login a ECR (04) usa un **token efímero** (`aws ecr get-login-password`).
- Las tareas que manejan valores sensibles llevan `no_log: true`.
- Las credenciales AWS provienen del **entorno**, no de los archivos.

**Idempotencia (re-ejecutable sin romper):**
- **01**: `prisma migrate deploy` solo aplica migraciones **pendientes**; si están
  al día, no hace nada (se marca `changed=false`).
- **02**: `INSERT ... ON CONFLICT (numero) DO NOTHING` sobre el `UNIQUE` de
  `numero`; reaplicar no duplica habitaciones.
- **03**: el módulo compara el valor actual del secret; si no cambió, no crea una
  versión nueva (`changed=false`).
- **04**: `docker build` reutiliza caché; el rollout usa `community.aws.ecs_service`
  con `force_new_deployment` (rolling, sin downtime). Se omite `desired_count`
  porque lo gobierna Application Auto Scaling, y se pasa la **familia** de task
  definition sin revisión para tomar siempre la última ACTIVE.
