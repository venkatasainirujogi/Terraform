variable "aws_region" {
  description = "AWS Region to deploy resources in"
  type        = string
  default     = "ap-south-1"
  
}
variable "ami_id" {
    type = string
    default = ""
  
}

variable "instance_type" {
    type = string
    default = ""
  
}
variable "cidr_block" {
    type = string
    default = ""
}
variable "username" {
    type = string
    default = ""
  
}
variable "password" {
    type = string
    default = ""
  
}
variable "instance_class " {
  type = string
    default = ""
}
variable "engine" {
    type = string
        default = ""
}

