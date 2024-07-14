variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "alb_listener_arns" {
  default = []
}

variable "blue_target_group_name" {
  type = string
  description = "ALB Target group name #1"
}

variable "green_target_group_name" {
  type = string
  description = "ALB Target group name #2"
}