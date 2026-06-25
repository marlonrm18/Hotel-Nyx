provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      Component = "tf-backend-bootstrap"
      ManagedBy = "terraform"
    }
  }
}
