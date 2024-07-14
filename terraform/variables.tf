variable "github_personal_token" {
  type        = string
  description = "GitHub personal access token: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens"
  default     = ""
}

variable "github_repository" {
  type        = string
  description = "Repository URL contained source code to build"
  default     = "https://github.com/shockfish/hello-world.git"
}

variable "github_repository_branch" {
  type        = string
  description = "Repository branch"
  default     = "main"
}

variable "postgres_user" {
  type        = string
  description = "User for RDS postgres instance. Used only once during DB creation. Credentials will be saved to SecretsManager"
  default     = "sa"
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

variable "ecs_container_port" {
  type = number
  description = "Container exposed port"
  default = 5000
}

variable "ecs_container_name" {
  type = string
  description = "Container name"
  default = "hello-world-web"
}