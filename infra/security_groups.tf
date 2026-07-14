# ------------------------------------------------------------------
# Security groups
#
# app_sg: shared by the ALB and EC2 instances (matches the original
# deployment's launch-wizard-1 group — HTTP 80, Flask port, SSH).
# db_sg: RDS only accepts MySQL traffic from app_sg, nothing else.
# ------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "image-app-sg"
  description = "Shared by ALB and EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet (ALB)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask app port"
    from_port   = var.flask_app_port
    to_port     = var.flask_app_port
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "SSH (restrict this to your IP in a real deployment)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "image-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "image-app-db-sg"
  description = "RDS: only accepts MySQL traffic from the app security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app/lambda security group only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "image-app-db-sg" }
}
