# ─────────────────────────────────────────────
#  vpc_endpoints.tf — VPC Endpoints (S3 + SQS)
# ─────────────────────────────────────────────

# ── S3 Gateway Endpoint (gratuito) ───────────
# Inyecta rutas a S3 en las tablas de rutas privadas;
# el tráfico nunca sale a internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_az_a.id,
    aws_route_table.private_az_b.id,
  ]

  tags = { Name = "${local.prefix}-vpce-s3" }
}

# ── SQS Interface Endpoint ────────────────────
# ENI en cada subnet privada → crop-lambda puede consumir SQS
# sin salir a internet ni usar NAT Gateway.
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_az_a.id,
    aws_subnet.private_az_b.id,
  ]

  security_group_ids = [aws_security_group.vpce_sqs.id]

  tags = { Name = "${local.prefix}-vpce-sqs" }
}
