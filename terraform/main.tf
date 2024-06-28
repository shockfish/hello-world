data "aws_region" "current" {}
locals {
  azs = formatlist("${data.aws_region.current.name}%s", ["a","b"])
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "ecs-vpc"
  cidr = "10.0.0.0/16"
  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_group_name = "rds"
  default_security_group_egress = [{
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = {
    ManagedBy = "terraform"
  }
}

module "rds_sg" {
  source = "terraform-aws-modules/security-group/aws"
  name = "rds-postgres-sg"
  description = "Security group for RDS postgres instance"
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port = 5432
      to_port = 5432
      protocol = "tcp"
      description = "Postgres"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "hello-world-db"
  engine            = "postgres"
  engine_version    = "12.19"
  instance_class    = "db.t3.micro"
  storage_type = "gp2"
  allocated_storage = 20
  family = "postgres12"

  db_name  = var.postgres_database
  username = var.postgres_user
  port     = var.postgres_port
  password = var.postgres_password

  manage_master_user_password = false

  apply_immediately = true
  deletion_protection = true

  vpc_security_group_ids = [module.rds_sg.security_group_id]
  subnet_ids             = module.vpc.database_subnets
  db_subnet_group_name = module.vpc.database_subnet_group_name

  tags = {
    ManagedBy = "terraform"
  }
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "hello-world"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 5 images",
        selection = {
          tagStatus     = "any",
          countType     = "imageCountMoreThan",
          countNumber   = 5
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  tags = {
    ManagedBy = "terraform"
  }
}

module "code-build" {
  source = "cloudposse/codebuild/aws"

  name = "hello-world-build"
  source_type = "GITHUB"
  source_location = var.github_repository
  source_version = var.github_repository_branch
  source_credential_auth_type = "PERSONAL_ACCESS_TOKEN"
  source_credential_server_type = "GITHUB"
  source_credential_token = var.github_personal_token
  private_repository = true
  privileged_mode = true
  build_timeout = 5
  artifact_type = "NO_ARTIFACTS"
  build_compute_type = "BUILD_GENERAL1_SMALL"
  build_image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
  buildspec = <<-EOT
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
    ManagedBy = "terraform"
  }
}

module "ecs" {
  source = "./modules/ecs"

  postgres_host = module.rds.db_instance_address
  postgres_port = module.rds.db_instance_port
  postgres_database = var.postgres_database
  postgres_password = var.postgres_password
  postgres_user = var.postgres_user
  ecs_subnet_ids = module.vpc.public_subnets
  ecs_vpc_id = module.vpc.vpc_id
  ecs_alb_target_group_arn = module.alb.target_groups["hello_world_app"].arn
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
      from_port   = 5000
      to_port     = 5000
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
        target_group_key = "hello_world_app"
      }
    }
  }

  target_groups = {
    hello_world_app = {
      name_prefix      = "hw"
      protocol         = "HTTP"
      port             = 5000
      target_type      = "ip"
      # Configuration requires any valid IP address to be specified
      # before ECS services will be registered in the group
      # In this case we specify dummy IP
      target_id        = "10.0.101.10"
    }
  }

  tags = {
    managedBy = "terraform"
    app     = "hello-world"
  }
}
