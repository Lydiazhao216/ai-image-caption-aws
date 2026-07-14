output "alb_dns_name" {
  description = "Public URL of the application (via the ALB)"
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "s3_bucket_name" {
  value = aws_s3_bucket.images.bucket
}
