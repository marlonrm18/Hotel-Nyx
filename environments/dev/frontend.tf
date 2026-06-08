# ─── KMS key: S3 frontend ─────────────────────────────────────────────────────

resource "aws_kms_key" "frontend" {
  description             = "${var.project}-${var.environment} — S3 frontend bucket"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-frontend-kms" }
}

resource "aws_kms_alias" "frontend" {
  name          = "alias/${var.project}-${var.environment}-frontend"
  target_key_id = aws_kms_key.frontend.key_id
}

# Política separada del key para romper la dependencia circular:
# aws_kms_key → aws_s3_bucket → aws_cloudfront_distribution → aws_kms_key_policy
resource "aws_kms_key_policy" "frontend" {
  key_id = aws_kms_key.frontend.id
  policy = data.aws_iam_policy_document.frontend_kms.json
}

data "aws_iam_policy_document" "frontend_kms" {
  statement {
    sid    = "EnableRootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # CloudFront OAC necesita Decrypt/GenerateDataKey para servir objetos SSE-KMS.
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

# ─── S3 bucket: frontend estático ─────────────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project}-${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.s3_frontend_force_destroy

  tags = { Name = "${var.project}-${var.environment}-frontend" }
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.frontend.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter { prefix = "" }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Política: solo CloudFront OAC puede leer objetos. Depende de la distribución.
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

# ─── ACM Certificate (us-east-1) para CloudFront ─────────────────────────────
# CloudFront solo acepta certificados en us-east-1, independientemente de la
# región principal del proyecto.

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project}-${var.environment}-cert-cloudfront" }
}

# Reutiliza los registros CNAME ya creados en alb.tf: AWS ACM usa el mismo
# registro _xxx.hotelnyx.com para validar *.hotelnyx.com y hotelnyx.com en
# cualquier región, evitando registros duplicados en Route 53.
resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ─── CloudFront Origin Access Control (OAC) ───────────────────────────────────

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-${var.environment}-frontend-oac"
  description                       = "OAC Hotel Nyx frontend S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ─── CloudFront Distribution ──────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project}-${var.environment} frontend SPA"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  web_acl_id = var.cloudfront_web_acl_arn != "" ? var.cloudfront_web_acl_arn : null

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # AWS Managed Policies: CachingOptimized + CORS-S3Origin.
    # No se pueden especificar TTL inline cuando cache_policy_id está definido.
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  # SPA routing: S3 devuelve 403 para rutas inexistentes → servir index.html con 200.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project}-${var.environment}-cf-distribution" }
}
