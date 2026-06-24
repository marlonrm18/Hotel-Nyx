output "domain_identity_arn" {
  description = "ARN de la identidad de dominio SES (usado en políticas IAM)"
  value       = aws_ses_domain_identity.main.arn
}

output "verification_token" {
  description = "Token TXT de verificación SES (ya publicado en Route 53)"
  value       = aws_ses_domain_identity.main.verification_token
}

output "mail_from_domain" {
  description = "Subdominio MAIL FROM configurado para SES"
  value       = aws_ses_domain_mail_from.main.mail_from_domain
}

output "vpc_endpoint_id" {
  description = "ID del VPC Interface Endpoint de SES (PrivateLink)"
  value       = aws_vpc_endpoint.ses.id
}

output "vpc_endpoint_dns" {
  description = "DNS privado del endpoint SES"
  value       = aws_vpc_endpoint.ses.dns_entry[0]["dns_name"]
}
