output "database_connection_string" {
  value = "${module.rds.db_instance_engine}://${var.postgres_user}:<password>@${module.rds.db_instance_address}:${module.rds.db_instance_port}"
}

output "application_endpoint" {
  description = "Application endpoint with GET and PUT methods accepted"
  value = "http://${module.alb.dns_name}/hello"
}