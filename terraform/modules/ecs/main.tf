data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_execution_role_tp" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_role_tp.json
}

data "aws_iam_policy" "ecs_execution_policy_managed" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_execution_policy_managed.arn
}

data "aws_iam_policy_document" "ecs_access_to_secret" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]
    resources = [var.postgres_secret_arn]
  }
}

resource "aws_iam_role_policy" "ecs_access_to_secret" {
  name   = "ecs_access_to_secret"
  policy = data.aws_iam_policy_document.ecs_access_to_secret.json
  role   = aws_iam_role.ecs_execution_role.id
}

resource "aws_ecs_task_definition" "hello-world" {
  family                   = var.ecs_task_family
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = templatefile("${path.root}/templates/taskdef.json.tftpl", {
    render_container_definition_only = true
    image                            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/hello-world:latest"
    container_name                   = var.ecs_container_name
    container_port                   = var.ecs_container_port
    postgres_host                    = var.postgres_host
    postgres_port                    = var.postgres_port
    postgres_database                = var.postgres_database
    postgres_secret_arn              = var.postgres_secret_arn
    execution_role_arn               = aws_iam_role.ecs_execution_role.arn
  })
}

module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws//modules/cluster"
  cluster_name = "ecs-hello-world"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
      }
    }
  }

  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service"
  description = "Group associated with ECS service"
  vpc_id      = var.ecs_vpc_id

  ingress {
    from_port   = var.ecs_container_port
    to_port     = var.ecs_container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}

module "ecs_service" {
  source                   = "terraform-aws-modules/ecs/aws//modules/service"
  name                     = var.ecs_task_family
  cluster_arn              = module.ecs_cluster.arn
  create_task_definition   = false
  task_definition_arn      = aws_ecs_task_definition.hello-world.arn
  family                   = var.ecs_task_family
  requires_compatibilities = ["FARGATE"]
  subnet_ids               = var.ecs_subnet_ids
  assign_public_ip         = true
  desired_count            = 1
  create_security_group    = true
  security_group_ids       = [aws_security_group.ecs_service_sg.id]
  deployment_controller = {
    type = "CODE_DEPLOY"
  }
  load_balancer = {
    service = {
      target_group_arn = var.ecs_alb_target_group_arn
      container_name   = var.ecs_container_name
      container_port   = var.ecs_container_port
    }
  }
  tags = {
    managedBy = "terraform"
    app       = "hello-world"
  }
}
