terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # us_east_1: ACM solo emite certs de CloudFront en us-east-1.
      configuration_aliases = [aws.us_east_1]
    }
  }
}
