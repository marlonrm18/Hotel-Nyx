output "zone_id" {
  description = "ID de la hosted zone Route 53"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers de la hosted zone (delegar desde el registrar)"
  value       = aws_route53_zone.main.name_servers
}
