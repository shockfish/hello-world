output "ecs_cluster_name" {
  value = module.ecs_cluster.name
}

output "ecs_service_name" {
  value = module.ecs_service.name
}

output "ecs_service_arn" {
  value = module.ecs_service.id
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}