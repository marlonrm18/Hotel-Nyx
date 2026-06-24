# ─── Hosted Zone ─────────────────────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project}-${var.environment}-zone"
  }
}

# ─── Alias records: raíz + www → CloudFront ──────────────────────────────────
# CloudFront soporta IPv6 (is_ipv6_enabled = true) → se crean registros A y AAAA.
# El hosted_zone_id de CloudFront es siempre Z2FDTNDATAQYW2 (constante global).

locals {
  cf_alias_records = {
    "apex_A"    = { name = var.domain_name, type = "A" }
    "apex_AAAA" = { name = var.domain_name, type = "AAAA" }
    "www_A"     = { name = "www.${var.domain_name}", type = "A" }
    "www_AAAA"  = { name = "www.${var.domain_name}", type = "AAAA" }
  }
}

resource "aws_route53_record" "cloudfront" {
  for_each = local.cf_alias_records

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# ─── Alias record: api.hotelnyx.com → API Gateway custom domain ───────────────
# Solo registro A: API Gateway Regional HTTP API no expone endpoint IPv6.

resource "aws_route53_record" "api_gateway" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
