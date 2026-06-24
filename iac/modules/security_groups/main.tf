# Patrón: SGs declarados sin reglas inline; todas las reglas son recursos
# independientes. Esto elimina la dependencia circular ALB↔ECS y ECS↔RDS.

# ─── Security Group: ALB ─────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-sg-alb"
  description = "ALB: HTTPS/HTTP publico entrante, salida restringida a ECS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-sg-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Puerto 80 necesario para que el listener de redirect HTTP→HTTPS funcione.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde internet (redirect 80->443 en ALB listener)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs_reservas" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB -> svc-reservas"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs_pagos" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB -> svc-pagos"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

# ─── Security Group: ECS ─────────────────────────────────────────────────────

resource "aws_security_group" "ecs" {
  name        = "${var.project}-${var.environment}-sg-ecs"
  description = "ECS Fargate: entrante solo desde SG-ALB, salida a RDS y AWS APIs"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-sg-ecs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_reservas_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "svc-reservas (3000) desde ALB"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_pagos_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "svc-pagos (3001) desde ALB"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# HTTPS saliente: ECR image pull, Secrets Manager, CloudWatch Logs, SES via NAT.
# Cuando el VPC endpoint de SES esté activo, ese trafico se resuelve por
# PrivateLink sin salir al NAT.
resource "aws_vpc_security_group_egress_rule" "ecs_to_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "HTTPS saliente (ECR, Secrets Manager, CloudWatch, SES)"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ECS -> RDS PostgreSQL"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
}

# ─── Security Group: RDS ─────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-sg-rds"
  description = "RDS PostgreSQL: entrante solo desde SG-ECS, sin salida"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-sg-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL (5432) desde ECS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

# RDS no inicia conexiones salientes: ningun egress rule declarado.

# ─── Security Group: VPC Interface Endpoints ─────────────────────────────────
# Usado por el endpoint de SES (PrivateLink) que se crea en el módulo ses.

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-${var.environment}-sg-vpc-endpoints"
  description = "VPC Interface Endpoints: entrante HTTPS solo desde SG-ECS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-sg-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_from_ecs" {
  security_group_id            = aws_security_group.vpc_endpoints.id
  description                  = "HTTPS desde ECS hacia endpoints PrivateLink"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}
