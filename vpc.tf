# ─────────────────────────────────────────────
#  vpc.tf — Red privada
# ─────────────────────────────────────────────

# ── VPC ───────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = local.vpc_name }
}

# ── Subnets públicas ──────────────────────────
resource "aws_subnet" "public_az_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az_a_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "${local.prefix}-public-a" }
}

resource "aws_subnet" "public_az_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az_b_cidr
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = { Name = "${local.prefix}-public-b" }
}

# ── Subnets privadas ──────────────────────────
resource "aws_subnet" "private_az_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az_a_cidr
  availability_zone = "${var.region}a"
  tags = { Name = "${local.prefix}-private-a" }
}

resource "aws_subnet" "private_az_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az_b_cidr
  availability_zone = "${var.region}b"
  tags = { Name = "${local.prefix}-private-b" }
}

# ── Internet Gateway ──────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-igw" }
}

# ── EIPs y NAT Gateways (uno por AZ) ─────────
resource "aws_eip" "nat_az_a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${local.prefix}-eip-a" }
}

resource "aws_eip" "nat_az_b" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${local.prefix}-eip-b" }
}

resource "aws_nat_gateway" "az_a" {
  allocation_id = aws_eip.nat_az_a.id
  subnet_id     = aws_subnet.public_az_a.id
  tags          = { Name = "${local.prefix}-nat-a" }
}

resource "aws_nat_gateway" "az_b" {
  allocation_id = aws_eip.nat_az_b.id
  subnet_id     = aws_subnet.public_az_b.id
  tags          = { Name = "${local.prefix}-nat-b" }
}

# ── Tabla de rutas pública ────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.prefix}-rt-public" }
}

resource "aws_route_table_association" "public_az_a" {
  subnet_id      = aws_subnet.public_az_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az_b" {
  subnet_id      = aws_subnet.public_az_b.id
  route_table_id = aws_route_table.public.id
}

# ── Tablas de rutas privadas ──────────────────
resource "aws_route_table" "private_az_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.az_a.id
  }
  tags = { Name = "${local.prefix}-rt-private-a" }
}

resource "aws_route_table" "private_az_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.az_b.id
  }
  tags = { Name = "${local.prefix}-rt-private-b" }
}

resource "aws_route_table_association" "private_az_a" {
  subnet_id      = aws_subnet.private_az_a.id
  route_table_id = aws_route_table.private_az_a.id
}

resource "aws_route_table_association" "private_az_b" {
  subnet_id      = aws_subnet.private_az_b.id
  route_table_id = aws_route_table.private_az_b.id
}

# ── Security Group: VPCE SQS ──────────────────
# Permite que las Lambdas llamen al endpoint SQS por HTTPS
resource "aws_security_group" "vpce_sqs" {
  name        = "${local.prefix}-sg-vpce-sqs"
  description = "Permite HTTPS entrante desde subnets privadas hacia el VPC Endpoint de SQS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde subnets privadas"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.private_subnet_az_a_cidr, var.private_subnet_az_b_cidr]
  }

  egress {
    description = "Sin salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["127.0.0.1/32"]
  }

  tags = { Name = "${local.prefix}-sg-vpce-sqs" }
}

# ── Security Group: upload-lambda ─────────────
resource "aws_security_group" "upload_lambda" {
  name        = "${local.prefix}-sg-upload-lambda"
  description = "SG de la upload-lambda — sin inbound, salida hacia S3 y HTTPS"
  vpc_id      = aws_vpc.main.id

  # HTTPS para llamadas a APIs de AWS (p.ej. STS, credenciales)
  egress {
    description = "HTTPS general"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # S3 Gateway Endpoint — tráfico a prefijos de S3 (sin pasar por internet)
  egress {
    description     = "S3 Gateway Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
  }

  tags = { Name = "${local.prefix}-sg-upload-lambda" }
}

# ── Security Group: crop-lambda ───────────────
resource "aws_security_group" "crop_lambda" {
  name        = "${local.prefix}-sg-crop-lambda"
  description = "SG de la crop-lambda — sin inbound, salida hacia S3, SQS VPCE y HTTPS"
  vpc_id      = aws_vpc.main.id

  # HTTPS general (STS, CloudWatch Logs, etc.)
  egress {
    description = "HTTPS general"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # S3 Gateway Endpoint
  egress {
    description     = "S3 Gateway Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
  }

  # SQS Interface Endpoint (ENI dentro de la VPC)
  egress {
    description     = "SQS Interface Endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpce_sqs.id]
  }

  tags = { Name = "${local.prefix}-sg-crop-lambda" }
}
