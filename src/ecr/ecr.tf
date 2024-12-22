resource "aws_ecr_repository" "lambda_repository" {
  name = "my-ecr-repo"
}


output "ecr_repository_url" {
  value = aws_ecr_repository.lambda_repository.repository_url
}

resource "null_resource" "docker_build_and_push" {
  # Use depends_on to ensure ECR is created before running Docker commands
  depends_on = [aws_ecr_repository.lambda_repository]

  provisioner "local-exec" {
    command = <<EOT
      cd  ../
      # Build the Docker image
      docker build -t my-app:latest .

      # Authenticate Docker with ECR
      aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.lambda_repository.repository_url}

      # Tag the Docker image
      docker tag my-app:latest "${aws_ecr_repository.lambda_repository.repository_url}:latest"

      # Push the Docker image to ECR
      docker push "${aws_ecr_repository.lambda_repository.repository_url}:latest"
    EOT
  }
}

