variable "region" {
  default = "ap-south-1"
}


provider "aws" {
  region = var.region
}

module "ecr" {
   source = "./ecr"
  }