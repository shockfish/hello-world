data "aws_region" "current" {}
locals {
  azs = formatlist("${data.aws_region.current.name}%s", ["a", "b"])
}

module "vpc" {
  source                     = "terraform-aws-modules/vpc/aws"
  name                       = "ecs-vpc"
  cidr                       = "10.0.0.0/16"
  azs                        = local.azs
  private_subnets            = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets             = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets           = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_group_name = "rds"
  default_security_group_egress = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

module "rds_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "rds-postgres-sg"
  description = "Security group for RDS postgres instance"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Postgres"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier        = "hello-world-db"
  engine            = "postgres"
  engine_version    = "12.19"
  instance_class    = "db.t3.micro"
  storage_type      = "gp2"
  allocated_storage = 20
  family            = "postgres12"

  db_name  = var.postgres_database
  username = var.postgres_user
  port     = var.postgres_port

  manage_master_user_password = true

  apply_immediately   = true
  deletion_protection = true

  vpc_security_group_ids = [module.rds_sg.security_group_id]
  subnet_ids             = module.vpc.database_subnets
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                 = "hello-world"
  repository_image_tag_mutability = "MUTABLE" # <--- For testing purposes only
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 5 images",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

module "code-build" {
  source = "cloudposse/codebuild/aws"

  name                          = "hello-world-build"
  source_type                   = "GITHUB"
  source_location               = var.github_repository
  source_version                = var.github_repository_branch
  source_credential_auth_type   = "PERSONAL_ACCESS_TOKEN"
  source_credential_server_type = "GITHUB"
  source_credential_token       = var.github_personal_token
  private_repository            = true
  privileged_mode               = true
  build_timeout                 = 5
  artifact_type                 = "NO_ARTIFACTS"
  build_compute_type            = "BUILD_GENERAL1_SMALL"
  build_image                   = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  buildspec                     = <<-EOT
  version: 0.2
  phases:
    pre_build:
      commands:
        - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    build:
      commands:
        - docker build --tag "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-world:latest" .
    post_build:
      commands:
        - docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-world:latest"
  EOT

  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

resource "aws_codebuild_webhook" "github_hello_world" {
  project_name = module.code-build.project_name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.github_repository_branch}"
    }
  }
}

module "ecs" {
  source = "./modules/ecs"
  postgres_host            = module.rds.db_instance_address
  postgres_port            = module.rds.db_instance_port
  postgres_database        = var.postgres_database
  postgres_secret_arn      = module.rds.db_instance_master_user_secret_arn
  ecs_subnet_ids           = module.vpc.public_subnets
  ecs_vpc_id               = module.vpc.vpc_id
  ecs_alb_target_group_arn = module.alb.target_groups["hello_world_blue"].arn
}

locals {
  tg_health_checks = {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = var.ecs_container_port
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "hello-world-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    allow_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    allow_5000 = {
      from_port   = var.ecs_container_port
      to_port     = var.ecs_container_port
      ip_protocol = "tcp"
      description = "Service port"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = {
    default = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "hello_world_blue"
      }
    }
  }

  target_groups = {
    hello_world_blue = {
      name        = "hello-blue"
      protocol    = "HTTP"
      port        = var.ecs_container_port
      target_type = "ip"
      # Configuration requires any valid IP address to be specified
      # before ECS services will be registered in the group
      # In this case we specify dummy IP
      target_id    = "10.0.101.10"
      health_check = local.tg_health_checks
    }

    hello_world_green = {
      name         = "hello-green"
      protocol     = "HTTP"
      port         = var.ecs_container_port
      target_type  = "ip"
      target_id    = "10.0.101.10"
      health_check = local.tg_health_checks
    }
  }

  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

module "codedeploy" {
  source                  = "./modules/codedeploy"
  alb_listener_arns       = module.alb.listeners["default"].arn
  ecs_cluster_name        = module.ecs.ecs_cluster_name
  ecs_service_name        = module.ecs.ecs_service_name
  blue_target_group_name  = module.alb.target_groups["hello_world_blue"].name
  green_target_group_name = module.alb.target_groups["hello_world_green"].name
}

module "codepipeline" {
  source                = "./modules/codepipeline"
  codedeploy_app_name   = module.codedeploy.codedeploy_app_name
  codedeploy_group_name = module.codedeploy.codedeploy_group_name
  ecr_repository_name   = module.ecr.repository_name
  ecs_service_arn       = module.ecs.ecs_service_arn
  ecs_task_role_arn     = module.ecs.ecs_task_role_arn
  postgres_secret_arn   = module.rds.db_instance_master_user_secret_arn
}