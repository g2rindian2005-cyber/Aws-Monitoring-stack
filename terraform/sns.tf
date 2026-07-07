resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-infra-alerts"

  tags = {
    Environment = var.environment
    Project     = "aws-infra-monitoring"
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# NOTE: After 'terraform apply', AWS sends a confirmation email to alert_email.
# You MUST click the confirmation link, or you will not receive any alarm notifications.

output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "ARN of the SNS topic used for all CloudWatch alarms"
}
