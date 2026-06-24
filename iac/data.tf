# Data sources genéricos pasados como inputs a los módulos que los necesitan
# (KMS, IAM, RDS) para construir ARNs y key policies.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
