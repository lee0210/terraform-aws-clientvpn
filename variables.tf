variable "vpc_id" {
  type        = string
  description = "The VPC ID to create ClientVPN endpoint"
}

variable "subnet_ids" {
  type        = list(string)
  description = "The list of subnet IDs to be associated with ClientVPN endpoint"
}

variable "build_folder" {
  type        = string
  description = "The build folder that stores generated client certificate"
  default     = ".build/clientvpn"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC, used to split traffic"
}

variable "client_cidr_block" {
  type        = string
  description = "The CIDR block of the ClientVPN"
}
