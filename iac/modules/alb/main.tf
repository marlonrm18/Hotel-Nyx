# ─── ACM Certificate (regional, us-east-2) ───────────────────────────────────
# Cubre hotelnyx.com y *.hotelnyx.com → sirve al ALB y al API Gateway Regional.
# El cert de CloudFront (us-east-1) va en el módulo frontend con el provider alias
# y reutiliza los mismos registros CNAME de validación (output cert_validation_fqdns).

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-cert-main"
  }
}

# Registros CNAME de validación DNS — uno por entrada única en domain_validation_options.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ─── Application Load Balancer ────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # Solucion al fallo de checkov "CKV_AWS_150"
  # Nota adicional: cuando destruyamos cambiar a false si no, no destruira el ALB
  enable_deletion_protection = true

  dynamic "access_logs" {
    for_each = var.alb_access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = "${var.project}/${var.environment}/alb"
      enabled = true
    }
  }

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# ─── Target Group: svc-reservas ───────────────────────────────────────────────

resource "aws_lb_target_group" "reservas" {
  name        = "${var.project}-${var.environment}-tg-reservas"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project}-${var.environment}-tg-reservas"
    Service = "svc-reservas"
  }
}

# ─── Target Group: svc-pagos ──────────────────────────────────────────────────

resource "aws_lb_target_group" "pagos" {
  name        = "${var.project}-${var.environment}-tg-pagos"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project}-${var.environment}-tg-pagos"
    Service = "svc-pagos"
  }
}

# ─── Listener: HTTP 80 → redirect permanente a HTTPS ─────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ─── Listener: HTTPS 443 ──────────────────────────────────────────────────────
# Política TLS: soporta TLS 1.2 y TLS 1.3, elimina cifrados débiles.

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({ error = "not found" })
      status_code  = "404"
    }
  }
}

# ─── Reglas de ruteo por path ─────────────────────────────────────────────────

resource "aws_lb_listener_rule" "reservas" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reservas.arn
  }

  condition {
    path_pattern {
      values = var.alb_reservas_path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "pagos" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pagos.arn
  }

  condition {
    path_pattern {
      values = var.alb_pagos_path_patterns
    }
  }
}
