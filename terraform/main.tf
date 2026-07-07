# --- Optional single-pane-of-glass CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "infra_overview" {
  dashboard_name = "${var.environment}-infra-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# ${upper(var.environment)} Infrastructure Monitoring Overview"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for id in var.ec2_instance_ids : ["AWS/EC2", "CPUUtilization", "InstanceId", id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "RDS Free Storage Space"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for id in var.rds_instance_ids : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5xx Errors"
          view   = "timeSeries"
          region = var.aws_region
          metrics = var.alb_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ] : []
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            for fn in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", fn]
          ]
        }
      }
    ]
  })
}
