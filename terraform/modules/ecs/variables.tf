variable "ecs_subnet_ids" {
  default = []
}

variable "ecs_vpc_id" {
  default = ""
}

variable "ecs_alb_target_group_arn" {
  default = ""
}

variable "postgres_user" {
  type = string
  description = "User for RDS postgres instance"
  default = "sa"
}

variable "postgres_password" {
  type = string
  description = "Password for RDS postgres instance"
  default = "ChangeME!"
  sensitive = true
}

variable "postgres_database" {
  type = string
  description = "RDS postgres database name"
  default = "hello_world"
}

variable "postgres_port" {
  type        = string
  description = "RDS postgres port"
  default     = "5432"
}

variable "postgres_host" {
  type = string
  description = "RDS instance address"
  default = "localhost"
}