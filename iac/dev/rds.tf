# ─── KMS: cifrado de RDS ─────────────────────────────────────────────────────

resource "aws_kms_key" "rds" {
  description             = "${var.project}-${var.environment}: cifrado RDS PostgreSQL"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── DB Subnet Group ─────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

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

# ─── Credenciales: random_password + Secrets Manager ─────────────────────────

resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.project}/${var.environment}/rds/credentials"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = { Name = "${var.project}-${var.environment}-secret-rds" }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.rds_db_name
    username = var.rds_master_username
    password = random_password.rds.result
  })
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
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
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
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.rds_db_name
  username = var.rds_master_username
  password = random_password.rds.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
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
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
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
