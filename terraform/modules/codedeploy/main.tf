data "aws_iam_policy_document" "codedeployrole_tp" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy_role" {
  name               = "codedeploy_role"
  assume_role_policy = data.aws_iam_policy_document.codedeployrole_tp.json
}

data "aws_iam_policy" "codedeploy_for_ecs_policy_managed" {
  arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = data.aws_iam_policy.codedeploy_for_ecs_policy_managed.arn
}

module "code_deploy_blue_green" {
  source = "cloudposse/code-deploy/aws"
  name   = "hello_world"

  create_default_service_role = false
  service_role_arn            = aws_iam_role.codedeploy_role.arn

  ecs_service = [
    {
      cluster_name = var.ecs_cluster_name
      service_name = var.ecs_service_name
    }
  ]

  load_balancer_info = {
    target_group_pair_info = {
      prod_traffic_route = {
        listener_arns = [var.alb_listener_arns]
      }
      blue_target_group = {
        name = var.blue_target_group_name
      }
      green_target_group = {
        name = var.green_target_group_name
      }
    }
  }

  traffic_routing_config = {
    type       = "AllAtOnce"
    interval   = 0
    percentage = 100
  }

  deployment_style = {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config = {
    deployment_ready_option = {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 2
    }
    terminate_blue_instances_on_deployment_success = {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 2
    }
  }

}