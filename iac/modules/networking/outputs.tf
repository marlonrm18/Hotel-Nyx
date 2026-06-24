output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas (índice = AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (índice = AZ)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "IPs públicas de los NAT Gateways (útil para whitelisting en servicios externos)"
  value       = aws_eip.nat[*].public_ip
}
