# --- RDS Free Storage Space Low Alarm ---
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  for_each = toset(var.rds_instance_ids)

  alarm_name          = "${var.environment}-rds-storage-low-${each.value}"
  alarm_description   = "RDS instance ${each.value} free storage below threshold"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_free_storage_threshold_bytes
  period              = 300
  evaluation_periods  = 2

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}

# --- RDS Instance Down / Not Available (via connection count as availability proxy) ---
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  for_each = toset(var.rds_instance_ids)

  alarm_name          = "${var.environment}-rds-cpu-high-${each.value}"
  alarm_description   = "RDS instance ${each.value} CPU utilization above 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  period              = 300
  evaluation_periods  = 2

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}
