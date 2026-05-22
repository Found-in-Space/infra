output "foundin_space_zone_id" {
  description = "Route 53 hosted zone ID for foundin.space."
  value       = aws_route53_zone.foundin_space.zone_id
}

output "foundin_space_name_servers" {
  description = "Authoritative name servers for foundin.space."
  value       = aws_route53_zone.foundin_space.name_servers
}

