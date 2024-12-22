variable "region" {
  default = "ap-south-1"
}


provider "aws" {
  region = var.region
}

#  }
 module "lambda" {
   source = "./lambda"
 }
