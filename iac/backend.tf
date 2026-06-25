# ─────────────────────────────────────────────────────────────────────────────
# Backend remoto (S3 + DynamoDB) para el state del IaC principal.
#
# CONFIGURACIÓN PARCIAL (recomendada): los valores que dependen de la cuenta
# —sobre todo el nombre del bucket, que es único globalmente— NO se hardcodean
# aquí. Se inyectan en `terraform init` con backend-config, de dos formas:
#
#   terraform init -backend-config=backend.hcl
#       (backend.hcl se genera a partir de los outputs del bootstrap; está
#        git-ignored — usa backend.hcl.example como plantilla)
#
#   o explícito:
#   terraform init \
#     -backend-config="bucket=hotel-nyx-tfstate-<sufijo>" \
#     -backend-config="dynamodb_table=hotel-nyx-tflocks"
#
# Así el código es portable entre cuentas/entornos sin tocar este archivo.
# Los valores que SÍ son estables viven aquí: key, region y encrypt.
# ─────────────────────────────────────────────────────────────────────────────
terraform {
  backend "s3" {
    key     = "hotel-nyx/dev/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true

    # bucket         = (se pasa por -backend-config; ver bootstrap)
    # dynamodb_table = (se pasa por -backend-config; ver bootstrap)
  }
}
