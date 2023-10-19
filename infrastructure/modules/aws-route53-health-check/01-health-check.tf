resource "aws_route53_health_check" "this" {
  failure_threshold = 2
  fqdn              = var.health_check_fqdn
  measure_latency   = true
  request_interval  = 10
  resource_path     = var.resource_path
  type              = "HTTPS"

  tags = {
    Name = var.name
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = "${var.name}-health-check-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "SampleCount"
  threshold           = "1"
  alarm_description   = "This triggers if the endpoint is down"
  alarm_actions       = [aws_sns_topic.this.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.this.id
  }
}

resource "aws_sns_topic" "this" {
  name = "${var.name}-health-check-alarm-topic"
}
