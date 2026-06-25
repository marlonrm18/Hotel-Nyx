# Bootstrap del backend remoto de Terraform (S3 + DynamoDB)

Crea la infraestructura mínima que aloja el **state remoto** del IaC principal:

- **Bucket S3** (`hotel-nyx-tfstate-<name_suffix>`): cifrado (AES256), **versionado**,
  **acceso público bloqueado** (4 flags), política que **deniega tráfico no-TLS** y
  `prevent_destroy`.
- **Tabla DynamoDB** (`hotel-nyx-tflocks`): **state locking** (clave `LockID` tipo
  `String`, `PAY_PER_REQUEST`), con PITR y `prevent_destroy`.

> ⚠️ Este módulo usa **state LOCAL** a propósito (no tiene bloque `backend`): no se
> puede guardar el state remoto en un bucket que aún no existe. Es la única
> excepción. Su `terraform.tfstate` queda git-ignored.

## Orden de operaciones (de cero a state remoto)

> **Solo necesito ejecutarlo yo cuando despliegue. Aquí nada se ejecuta.**

**Paso 0 — Bootstrap (UNA sola vez por cuenta/entorno):**
```bash
cd iac/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edita name_suffix (único global)
terraform init      # state local
terraform apply     # crea el bucket S3 + la tabla DynamoDB
terraform output    # anota state_bucket_name y lock_table_name
```

**Paso 1 — Inicializar el IaC principal contra el backend remoto:**
```bash
cd ..                       # ahora en iac/
cp backend.hcl.example backend.hcl   # rellena con los outputs del bootstrap
terraform init -backend-config=backend.hcl
```
- `key`, `region` y `encrypt` ya están en `backend.tf`; `bucket` y `dynamodb_table`
  los aporta `backend.hcl` (config parcial).
- **No hay state previo** en `iac/` (nunca se aplicó), así que esto **inicializa
  limpio** en remoto. Si en el futuro existiera un state local, `terraform init`
  preguntaría si migrarlo al backend remoto (`yes`).

**Paso 2 — Operar el IaC principal normalmente:**
```bash
terraform plan
terraform apply
```

## Notas

- El **bootstrap se aplica una vez** por cuenta/entorno; después casi nunca se toca.
- El nombre del **bucket S3 es único globalmente**: por eso `name_suffix` (account
  id, id aleatorio, etc.).
- El bucket y la tabla tienen `prevent_destroy`: para eliminarlos de verdad hay que
  quitar ese lifecycle a propósito (protección contra borrados accidentales del state).
- Para CI/CD, el bucket y la tabla se pasan al `terraform init` de los workflows vía
  secrets/variables de GitHub (`TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`). Ver
  `.github/README.md`.
