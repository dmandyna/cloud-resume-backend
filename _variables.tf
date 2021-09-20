variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "There AWS region to deploy the solution to."

  # validation {
  #   condition = contains(["us-east-1", "us-west-2", "eu-west-1", "eu-central-1"], var.region)
  #   error_message = "Valid values for the region are: us-east-1, us-west-2, eu-west-1 or eu-central-1"
  # }
}
