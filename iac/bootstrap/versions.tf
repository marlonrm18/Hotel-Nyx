# ─────────────────────────────────────────────────────────────────────────────
# Hotel Nyx — Bootstrap del backend remoto (S3 + DynamoDB).
#
# ⚠️ EXCEPCIÓN INTENCIONAL: este módulo usa STATE LOCAL (no hay bloque backend).
# Es el problema del huevo y la gallina: no podemos guardar el state remoto en un
# bucket que todavía no existe. Por eso el bootstrap se aplica UNA sola vez por
# cuenta/entorno con state local, y a partir de ahí el IaC principal (iac/) ya
# tiene dónde guardar su state remoto. Ver README.md.
# ─────────────────────────────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
