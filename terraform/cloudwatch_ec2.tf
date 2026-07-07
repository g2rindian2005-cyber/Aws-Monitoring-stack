# --- EC2 CPU Utilization Alarm ---
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  for_each = toset(var.ec2_instance_ids)

  alarm_name          = "${var.environment}-ec2-cpu-high-${each.value}"
  alarm_description   = "EC2 instance ${each.value} CPU utilization above ${var.ec2_cpu_threshold}%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.ec2_cpu_threshold
  period              = 300 # 5 minutes
  evaluation_periods  = 2   # must breach for 2 consecutive periods (10 min) to avoid noise
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}

# --- EC2 Instance Down (Status Check Failed) Alarm ---
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  for_each = toset(var.ec2_instance_ids)

  alarm_name          = "${var.environment}-ec2-instance-down-${each.value}"
  alarm_description   = "EC2 instance ${each.value} failed status checks (instance may be down)"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 3 # 3 consecutive minutes of failure

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}
