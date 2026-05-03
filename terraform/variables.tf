# ─────────────────────────────────────────────
#  variables.tf — Entradas del proyecto
# ─────────────────────────────────────────────

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El entorno debe ser dev, qa o prod."
  }
}

variable "region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}

# ── Red ───────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_az_a_cidr" {
  description = "CIDR subnet pública AZ-a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az_b_cidr" {
  description = "CIDR subnet pública AZ-b"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_az_a_cidr" {
  description = "CIDR subnet privada AZ-a"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_az_b_cidr" {
  description = "CIDR subnet privada AZ-b"
  type        = string
  default     = "10.0.12.0/24"
}

# ── Lambda ────────────────────────────────────
variable "upload_lambda_zip" {
  description = "Ruta al ZIP de upload-lambda"
  type        = string
  default     = "../dist/upload-lambda.zip"
}

variable "crop_lambda_zip" {
  description = "Ruta al ZIP de crop-lambda"
  type        = string
  default     = "../dist/crop-lambda.zip"
}

# ── Alertas ───────────────────────────────────
variable "alarm_email" {
  description = "Email para notificaciones SNS (alarma DLQ)"
  type        = string
  default     = "ops@example.com"
}
