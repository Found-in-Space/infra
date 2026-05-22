locals {
  dns_records_yaml = yamldecode(file("${path.module}/records.yaml"))

  dns_records = {
    for record in local.dns_records_yaml.records : record.id => {
      name    = record.name
      type    = record.type
      ttl     = try(tonumber(record.ttl), null)
      records = try(record.records, null)
      alias = try({
        evaluate_target_health = try(record.alias.evaluate_target_health, false)
        name                   = record.alias.name
        zone_id                = record.alias.zone_id
      }, null)
    }
  }

  standard_dns_records = {
    for id, record in local.dns_records : id => record
    if record.alias == null
  }

  alias_dns_records = {
    for id, record in local.dns_records : id => record
    if record.alias != null
  }
}

resource "aws_route53_record" "records" {
  for_each = local.standard_dns_records

  zone_id = aws_route53_zone.foundin_space.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

resource "aws_route53_record" "alias_records" {
  for_each = local.alias_dns_records

  zone_id = aws_route53_zone.foundin_space.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    evaluate_target_health = each.value.alias.evaluate_target_health
    name                   = each.value.alias.name
    zone_id                = each.value.alias.zone_id
  }
}

