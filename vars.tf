variable "company_name" {
  type        = string
  description = "Company name"
}

variable "AWS_REGION" {
  type        = string
  description = "The AWS Region where Terraform will depoy to"

}

## AWS Credential and Account Information
variable "aws_profile" {
  type        = string
  description = "The AWS CLI profile name representing the account to deploy Terraform"
}

variable "resource_tags" {
  default     = null
  type        = string
  description = "Additional Tags that need to be attached to every resource"

}
