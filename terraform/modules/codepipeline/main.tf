data "archive_file" "codepipeline_config" {
  type = "zip"
  source {
    content = templatefile("${path.module}/templates/appspec.yaml.tftpl", {
      container_name = var.ecs_container_name
      container_port = var.ecs_container_port
    })
    filename = "appspec.yaml"
  }
  source {
    content = templatefile("${path.root}/templates/taskdef.json.tftpl", {
      render_container_definition_only = false
      image                            = "<IMAGE1_NAME>"
      container_name                   = var.ecs_container_name
      container_port                   = var.ecs_container_port
      execution_role_arn               = var.ecs_task_role_arn
      postgres_host                    = var.postgres_host
      postgres_port                    = var.postgres_port
      postgres_database                = var.postgres_database
      postgres_secret_arn              = var.postgres_secret_arn
    })
    filename = "taskdef.json"
  }
  output_path = "${path.module}/templates/hello_world.zip"
}

locals {
  pipeline_bucket_names = ["codepipeline-config", "codepipeline-store"]
}

module "pipeline_buckets" {
  source  = "./modules/buckets"
  buckets = local.pipeline_bucket_names
}

resource "aws_s3_object" "codepipeline_config" {
  bucket = module.pipeline_buckets.buckets["codepipeline-config"].id
  key    = "hello_world.zip"
  source = "${path.module}/templates/hello_world.zip"
  etag   = filemd5("${path.module}/templates/hello_world.zip")
}

data "aws_iam_policy_document" "codepipeline_role_tp" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-hello-world-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_role_tp.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      values   = ["ecs-tasks.amazonaws.com"]
      variable = "iam:PassedToService"
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]
    resources = [
      module.pipeline_buckets.buckets["codepipeline-store"].arn,
      "${module.pipeline_buckets.buckets["codepipeline-store"].arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Describe*"
    ]
    resources = [
      module.pipeline_buckets.buckets["codepipeline-config"].arn,
      "${module.pipeline_buckets.buckets["codepipeline-config"].arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecs:*"
    ]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "codepipeline_rp" {
  name   = "codepipeline-role-policy"
  policy = data.aws_iam_policy_document.codepipeline_policy.json
  role   = aws_iam_role.codepipeline_role.id
}

resource "aws_codepipeline" "codepipeline" {
  name     = "hello-world"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = module.pipeline_buckets.buckets["codepipeline-store"].id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      category = "Source"
      name     = "Config"
      owner    = "AWS"
      provider = "S3"
      version  = "1"
      configuration = {
        S3Bucket    = aws_s3_object.codepipeline_config.bucket
        S3ObjectKey = aws_s3_object.codepipeline_config.key
      }
      output_artifacts = ["config"]
    }
    action {
      category = "Source"
      name     = "Image"
      owner    = "AWS"
      provider = "ECR"
      version  = "1"
      configuration = {
        RepositoryName = var.ecr_repository_name
      }
      output_artifacts = ["image"]
    }
  }
  stage {
    name = "Deploy"
    action {
      category        = "Deploy"
      name            = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["config", "image"]
      configuration = {
        ApplicationName                = var.codedeploy_app_name
        DeploymentGroupName            = var.codedeploy_group_name
        TaskDefinitionTemplateArtifact = "config"
        AppSpecTemplateArtifact        = "config"
        Image1ArtifactName             = "image"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
}