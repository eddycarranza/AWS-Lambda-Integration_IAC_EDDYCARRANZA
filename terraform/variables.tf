variable "environment" {
  type = string
}
variable "region" {
  type    = string
  default = "us-east-2"
}
variable "upload_lambda_zip" {
  type    = string
  default = "../dist/upload-lambda.zip"
}
variable "crop_lambda_zip" {
  type    = string
  default = "../dist/crop-lambda.zip"
}
