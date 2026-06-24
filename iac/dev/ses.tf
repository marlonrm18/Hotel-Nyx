# ─── SES Domain Identity ──────────────────────────────────────────────────────
# La verificación DNS puede tardar hasta 72 h; Terraform solo crea los recursos.
# No se usa aws_ses_domain_identity_verification para no bloquear el apply.

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_route53_record" "ses_verification" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

# ─── DKIM ─────────────────────────────────────────────────────────────────────
# SES genera 3 tokens; cada uno requiere su propio registro CNAME.

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# ─── MAIL FROM personalizado: mail.hotelnyx.com ───────────────────────────────
# Evita que el sobre From muestre amazonses.com, mejora la entregabilidad y
# habilita alineación DMARC (same-domain alignment).

resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain_name}"

  # Si falla el lookup MX del subdominio, SES vuelve al dominio raíz en vez de
  # rechazar el mensaje — comportamiento seguro para no perder correos.
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "mail.${var.domain_name}"
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "mail.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com -all"]
}

# ─── DMARC ────────────────────────────────────────────────────────────────────
# Política p=none en dev/staging (solo monitoreo); cambiar a p=quarantine/reject
# en producción tras revisar los reportes en alert_email.

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none; rua=mailto:${var.alert_email}"]
}

# ─── VPC Interface Endpoint: SES API ─────────────────────────────────────────
# Tráfico svc-reservas → SES API (SDK) viaja por PrivateLink sin pasar por NAT.
# El SG vpc_endpoints ya permite ingress 443 desde SG-ECS (security_groups.tf).

resource "aws_vpc_endpoint" "ses" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ses"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project}-${var.environment}-vpce-ses" }
}
