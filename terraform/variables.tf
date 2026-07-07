variable "aws_region" {
  description = "AWS region to deploy monitoring resources in"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used for tagging and naming"
  type        = string
  default     = "production"
}

variable "alert_email" {
  description = "Email address to receive SNS alert notifications"
  type        = string
}

# ---- EC2 ----
variable "ec2_instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "ec2_cpu_threshold" {
  description = "CPU utilization % threshold that triggers an alarm"
  type        = number
  default     = 80
}

# ---- RDS ----
variable "rds_instance_ids" {
  description = "List of RDS DB instance identifiers to monitor"
  type        = list(string)
  default     = []
}

variable "rds_free_storage_threshold_bytes" {
  description = "Free storage space (bytes) below which RDS alarm triggers. Default 2GB."
  type        = number
  default     = 2147483648
}

# ---- ALB ----
variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (e.g. app/my-alb/50dc6c495c0c9188)"
  type        = string
  default     = ""
}

variable "alb_5xx_threshold" {
  description = "Number of 5xx errors in the evaluation period that triggers an alarm"
  type        = number
  default     = 10
}

# ---- Lambda ----
variable "lambda_function_names" {
  description = "List of Lambda function names to monitor for errors"
  type        = list(string)
  default     = []
}

variable "lambda_error_threshold" {
  description = "Number of Lambda errors in the evaluation period that triggers an alarm"
  type        = number
  default     = 5
}

# ---- EKS ----
variable "eks_cluster_name" {
  description = "Name of the EKS cluster to monitor (for CloudWatch Container Insights alarms)"
  type        = string
  default     = ""
}
