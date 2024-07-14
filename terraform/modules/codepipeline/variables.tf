variable "ecr_repository_name" {
  type    = string
  default = "hello-world"
}

variable "codedeploy_app_name" {
  type    = string
  default = "hello-world"
}

variable "codedeploy_group_name" {
  type    = string
  default = "hello-world"
}

variable "ecs_service_arn" {
  type    = string
  default = ""
}

variable "ecs_task_role_arn" {
  type    = string
  default = ""
}

variable "ecs_container_port" {
  type        = number
  description = "Container exposed port"
  default     = 5000
}

variable "ecs_container_name" {
  type        = string
  description = "Container name"
  default     = "hello-world-web"
}

variable "postgres_secret_arn" {
  type        = string
  description = "AWS Secrets Manager secret ARN which contains credentials for RDS"
}

variable "postgres_database" {
  type        = string
  description = "RDS postgres database name"
  default     = "hello_world"
}

variable "postgres_port" {
  type        = string
  description = "RDS postgres port"
  default     = "5432"
}

variable "postgres_host" {
  type        = string
  description = "RDS instance address"
  default     = "localhost"
}