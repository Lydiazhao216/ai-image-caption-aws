# ------------------------------------------------------------------
# S3 bucket for uploads + thumbnails
# ------------------------------------------------------------------

resource "aws_s3_bucket" "images" {
  bucket = var.s3_bucket_name
  tags   = { Name = "image-app-bucket" }
}

# Original deployment disabled "block all public access" so uploaded
# images/thumbnails could be viewed directly via S3 URLs. A production
# version would instead keep the bucket private and serve images only
# through presigned URLs (the app already generates presigned URLs for
# the gallery page, so this public-access block could be re-enabled).
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ------------------------------------------------------------------
# RDS (MySQL)
# ------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "image-app-db-subnet-group"
  subnet_ids = [aws_subnet.private.id]

  tags = { Name = "image-app-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier             = "image-app-db"
  engine                 = "mysql"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 1000
  storage_type           = "gp2"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = { Name = "image-app-db" }
}
