provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "hotel-nyx"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Alias requerido por el módulo frontend: ACM sólo emite certs para
# CloudFront en us-east-1, independientemente de la región del bucket S3.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "hotel-nyx"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
