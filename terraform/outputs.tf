output "dashboard_url" {
  description = "Direct link to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.infra_overview.dashboard_name}"
}

output "alarm_count_summary" {
  description = "Count of alarms created per service"
  value = {
    ec2_cpu_alarms      = length(aws_cloudwatch_metric_alarm.ec2_cpu_high)
    ec2_down_alarms     = length(aws_cloudwatch_metric_alarm.ec2_status_check_failed)
    rds_storage_alarms  = length(aws_cloudwatch_metric_alarm.rds_storage_low)
    rds_cpu_alarms      = length(aws_cloudwatch_metric_alarm.rds_high_cpu)
    lambda_error_alarms = length(aws_cloudwatch_metric_alarm.lambda_errors)
  }
}
