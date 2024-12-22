# # Data source to fetch the existing ECR repository
# module "s3" {
#   source = "../s3"  # Adjust the path to where your infrastructure module is located
# }

data "aws_ecr_repository" "lambda_repository" {
  name = "my-ecr-repo"  # Replace with your ECR repository name
}

# data "aws_rds_instance" "rds" {
#   db_instance_identifier = "existing-db-instance-id"  # Use the actual identifier of the existing RDS instance
# }

# S3 configuration
# data "aws_region" "current" {}
variable "s3_bucket_name" {
  default = "td-bucket-69"
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "td-bucket-69"
}

resource "aws_s3_object" "default_object" {
  bucket = aws_s3_bucket.app_bucket.bucket
  key    = "data/input.json"  # The object key
  content = jsonencode({
    records = [
      { "id": 1, "name": "John Doe" }
    ]
  })
}
#output "s3_endpoint_id" {
 # value = "vpce-0e1669da3d37c9508"
#}


# VPC Endpoint for S3
# resource "aws_vpc_endpoint" "s3_endpoint" {
#   vpc_id        = "vpc-0a698fc6bb8659871"
#   service_name  = "com.amazonaws.${data.aws_region.current.name}.s3"
#   route_table_ids = ["rtb-0c606ce2731b29087"]

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = "s3:GetObject"
#         Resource = "arn:aws:s3:::td-bucket-69/*"
#       },
#       {
#         Effect   = "Allow"
#         Action   = "s3:ListBucket"
#         Resource = "arn:aws:s3:::td-bucket-69"
#       }
#     ]
#   })
# }


# Output for the S3 bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket
}


# RDS configuration
variable "db_name" {
  default = "app_db"
}

variable "db_user" {
  default = "admin"
}

variable "db_password" {
  default = "password123"
}


resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = "vpc-0a698fc6bb8659871"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change to allow only Lambda or trusted sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.39"
  instance_class       = "db.m5d.large"
  db_name                = var.db_name
  username             = var.db_user
  password             = var.db_password
  publicly_accessible  = true
  skip_final_snapshot  = true
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}



# lambda configuration
resource "aws_lambda_function" "app_function" {
  function_name = "s3-to-rds-function"
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.lambda_repository.repository_url}:latest"
  role          = aws_iam_role.lambda_execution_role.arn
  timeout       = 900 
  memory_size   = 1024
   depends_on = [
     aws_iam_role.lambda_execution_role,
     data.aws_ecr_repository.lambda_repository
   ]
   environment {
  variables = {
    example_bucket_name = aws_s3_bucket.app_bucket.bucket
    OBJECT_KEY          = aws_s3_object.default_object.key
    RDS_ENDPOINT        = aws_db_instance.rds.endpoint
    DB_USER             = aws_db_instance.rds.username
    DB_PASSWORD         = aws_db_instance.rds.password
    DB_NAME             = aws_db_instance.rds.db_name
  }
}
 vpc_config {
    subnet_ids         = ["subnet-06dd978cc6b4fa1c8", "subnet-043e69cc6de777555" , "subnet-0d4d69adf91974f89"]  # Replace with your subnet IDs
    security_group_ids = [aws_security_group.rds_sg.id]   # Using the same security group
  }

}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_security_group" "lambda_sg" {
  name        = "lambda_security_group"
  vpc_id      = "vpc-0a698fc6bb8659871"

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust as necessary for your setup
  }
}

resource "aws_iam_policy" "lambda_vpc_access" {
  name = "LambdaVpcAccessPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_vpc_access_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_vpc_access.arn
}


resource "aws_iam_policy" "s3_permissions_policy" {
  name = "s3_permissions_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:ListBucket",
        Resource = "arn:aws:s3:::td-bucket-69/*"
      },
      {
        Effect   = "Allow",
        Action   = "s3:GetObject",
        Resource = "arn:aws:s3:::td-bucket-69/data/input.json"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_permissions" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.s3_permissions_policy.arn
}
resource "aws_iam_policy" "lambda_ecr_access_policy" {
  name        = "LambdaECRAccessPolicy"
  description = "Policy granting access to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:BatchGetImage",
          "ecr:BatchGetLayer"
        ]
        Resource = "arn:aws:ecr:region:account-id:repository/repository-name"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_ecr_access_policy.arn
}

resource "aws_iam_policy" "rds_permissions_policy" {
  name = "rds_permissions_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "rds:DescribeDBInstances",
          "rds:connect"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_rds_permissions" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.rds_permissions_policy.arn
}


resource "aws_iam_policy_attachment" "lambda_policy_attach" {
  name       = "lambda-policy-attachment" # Policy attachment name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
  roles      = [aws_iam_role.lambda_execution_role.name]
}


