# --- ALB 5xx Errors Alarm (target-generated 5xx responses) ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-alb-5xx-errors"
  alarm_description   = "ALB is returning elevated 5xx errors from targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alb_5xx_threshold
  period              = 60
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}

# --- ALB Unhealthy Host Count (helps catch "instance down" behind the ALB) ---
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-alb-unhealthy-hosts"
  alarm_description   = "ALB has one or more unhealthy targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 3

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = var.environment
  }
}
