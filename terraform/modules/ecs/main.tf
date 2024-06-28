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
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_role_tp
}

data "aws_iam_policy" "ecs_execution_policy_managed" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role = aws_iam_role.ecs_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_execution_policy_managed.arn
}

resource "aws_ecs_task_definition" "hello-world" {
  family                   = "hello-world-web"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode(
    [
      {
        name = "hello-world-web",
        image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/hello-world:latest",
        cpu = 0,
        portMappings = [
          {
            name = "hello-world-5000-tcp",
            containerPort = 5000,
            hostPort = 5000,
            protocol = "tcp",
            appProtocol = "http"
          }
        ],
        essential = true,
        environment = [
          {
            name = "PGHOST",
            value = var.postgres_host
          },
          {
            name = "PGPORT",
            value = var.postgres_port
          },
          {
            name = "PGUSER",
            value = var.postgres_user
          },
          {
            name = "PGDATABASE",
            value = var.postgres_database
          },
          {
            name = "PGPASSWORD",
            value = var.postgres_password
          }
        ],
        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group = "/ecs/hello-world",
            awslogs-create-group = "true",
            awslogs-region = "us-east-1",
            awslogs-stream-prefix = "ecs"
          }
        }
      }
    ]
  )
}

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"

  cluster_name = "ecs-hello-world"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 1
      }
    }
  }

  tags = {
    ManagedBy     = "terraform"
  }
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service"
  description = "Group associated with ECS service"
  vpc_id      = var.ecs_vpc_id

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
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
    app = "hello-world"
  }
}

module "ecs_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"
  name = "hello-world-app"
  cluster_arn = module.ecs_cluster.arn
  create_task_definition = false
  task_definition_arn = aws_ecs_task_definition.hello-world.arn
  family = "hello-world-app"
  requires_compatibilities = ["FARGATE"]
  subnet_ids = var.ecs_subnet_ids
  assign_public_ip = true
  desired_count = 1
  create_security_group = true
  security_group_ids = [aws_security_group.ecs_service_sg.id]
  load_balancer = {
    service = {
      target_group_arn = var.ecs_alb_target_group_arn
      container_name   = "hello-world-web"
      container_port   = 5000
    }
  }
}
