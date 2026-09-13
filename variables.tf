variable "cluster" {
  description = "The cluster to bootstrap"
  type        = any
}

variable "subnet" {
  description = "The subnet CIDR block for the Function App. Must be /28"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/28$", var.subnet))
    error_message = "The subnet must be a valid CIDR block with a /28 mask"
  }
}

variable "charts" {
  description = "Helm charts to install"
  type = map(object({
    chart            = string
    repository       = optional(string, null)
    version          = optional(string, null)
    values           = optional(any, {})
    namespace        = optional(string, "default")
    wait             = optional(bool, true)
    timeout          = optional(string, "5m")
    create_namespace = optional(bool, true)
  }))
  default = null
}

variable "force" {
  description = "Force rebuilding the package and invoking the bootstrap"
  type        = bool
  default     = false
}

variable "sleep" {
  description = "The time to sleep after Helm chart installations"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
