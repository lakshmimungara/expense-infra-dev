variable "project_name" {
  default = "expense"
}

variable "environment" {
  default = "dev"
}

variable "common_tags" {
  default = {
    Project     = "expense"
    Terraform   = "true"
    Environment = "dev"
  }
}

variable "rds_tags" {
  default = {
    Component = "mysql" # this can be optional 
  }
}

variable "zone_name"{
  default = "daws81s.fun"
}