# Módulo route53: SOLO la hosted zone. Los registros DNS viven con su recurso
# consumidor para evitar dependencias circulares entre módulos:
#   - validación ACM regional  → módulo alb
#   - alias apex/www → CloudFront → módulo frontend
#   - alias api → API Gateway    → módulo api_gateway
#   - verificación/DKIM/MAIL FROM/DMARC → módulo ses
# Todos reciben este zone_id como input.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project}-${var.environment}-zone"
  }
}
