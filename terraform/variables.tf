variable "github_personal_token" {
  type = string
  description = "GitHub personal access token: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens"
  default = ""
}

variable "github_repository" {
  type = string
  description = "Repository URL contained source code to build"
  default = "https://github.com/shockfish/hello-world.git"
}

variable "github_repository_branch" {
  type = string
  description = "Repository branch"
  default = "main"
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
  type = string
  description = "RDS postgres port"
  default = "5432"
}