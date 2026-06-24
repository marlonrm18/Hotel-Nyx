# ─── DB Subnet Group ─────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.project}-${var.environment}-db-subnet-group" }
}

# ─── Parameter Group ─────────────────────────────────────────────────────────

locals {
  rds_pg_family = "postgres${split(".", var.rds_postgres_version)[0]}"
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-pg"
  family = local.rds_pg_family

  # Fuerza TLS en todas las conexiones a la BD.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project}-${var.environment}-pg" }
}

# ─── Credenciales: random_password ───────────────────────────────────────────
# La contraseña se genera aquí (la instancia la necesita en creación) y se
# exporta como output sensible para que el módulo secrets la guarde en
# Secrets Manager. La rotación posterior se gestiona vía Secrets Manager
# (ver lifecycle.ignore_changes en aws_db_instance).

resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ─── IAM Role: Enhanced Monitoring ───────────────────────────────────────────

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${var.project}-${var.environment}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = { Name = "${var.project}-${var.environment}-rds-monitoring" }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ─── RDS PostgreSQL Multi-AZ ─────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.rds_postgres_version
  instance_class = var.rds_instance_class

  storage_type          = "gp3"
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.rds_kms_key_arn

  db_name  = var.rds_db_name
  username = var.rds_master_username
  password = random_password.rds.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = true

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period  = var.rds_backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:30-Mon:05:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  # Exportar logs de PostgreSQL a CloudWatch Logs para auditoria.
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.rds_kms_key_arn
  performance_insights_retention_period = var.rds_performance_insights_retention

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  deletion_protection        = var.rds_deletion_protection
  skip_final_snapshot        = var.rds_skip_final_snapshot
  final_snapshot_identifier  = "${var.project}-${var.environment}-final-snapshot"
  apply_immediately          = false
  auto_minor_version_upgrade = true

  # ignore_changes en password: la rotacion se gestiona via Secrets Manager,
  # no mediante re-apply de Terraform, para evitar downtime no planificado.
  lifecycle {
    ignore_changes = [password]
  }

  tags = {
    Name = "${var.project}-${var.environment}-postgres"
  }
}
