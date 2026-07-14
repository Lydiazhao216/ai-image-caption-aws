variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread the ALB and ASG across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "instance_type" {
  description = "EC2 instance type for the web application"
  type        = string
  default     = "t2.micro"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 3
}

variable "asg_desired_capacity" {
  type    = number
  default = 1
}

variable "flask_app_port" {
  description = "Port the Flask app listens on inside the EC2 instance"
  type        = number
  default     = 5000
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  type    = string
  default = "8.0.41"
}

variable "db_name" {
  type    = string
  default = "image_caption_db"
}

variable "db_username" {
  description = "RDS master username. Set via TF_VAR_db_username, do not hardcode."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password. Set via TF_VAR_db_password, do not hardcode."
  type        = string
  sensitive   = true
}

variable "s3_bucket_name" {
  description = "Globally-unique S3 bucket name for uploads/thumbnails"
  type        = string
}

variable "gemini_api_key" {
  description = "Google Gemini API key, injected into the annotation Lambda's environment"
  type        = string
  sensitive   = true
}

variable "ec2_iam_role_name" {
  description = "IAM role attached to EC2 instances and Lambda functions. In the original sandbox deployment this was the AWS Academy default LabRole (broad permissions); a production setup should replace this with a least-privilege role scoped to only S3, RDS, Secrets Manager, and CloudWatch Logs access."
  type        = string
  default     = "image-app-role"
}
