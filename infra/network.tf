# ------------------------------------------------------------------
# VPC and networking
#
# Layout mirrors the original deployment: a public subnet per AZ for
# the ALB, a private subnet for EC2 + RDS + Lambda, outbound internet
# access from the private subnet routed through a NAT Gateway.
# ------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "image-app-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "image-app-igw" }
}

# One public subnet per AZ, for the ALB
resource "aws_subnet" "public" {
  for_each = toset(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.value))
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = { Name = "image-app-public-${each.value}" }
}

# Single private subnet for EC2 / RDS / Lambda (matches original single-AZ setup)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 100)
  availability_zone = var.availability_zones[0]

  tags = { Name = "image-app-private-${var.availability_zones[0]}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "image-app-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.availability_zones[0]].id
  tags          = { Name = "image-app-nat" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "image-app-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "image-app-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
