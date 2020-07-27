locals {
  OPERATOR_MAP = {
    ">"  = "GreaterThanThreshold"
    ">=" = "GreaterThanOrEqualToThreshold"
    "<"  = "LessThanThreshold"
    "<=" = "LessThanOrEqualToThreshold"
  }

  ANOMALY_OPERATOR_MAP = {
    "<>" = "LessThanLowerOrGreaterThanUpperThreshold"
    "<"  = "LessThanLowerThreshold"
    ">"  = "GreaterThanUpperThreshold"
  }

  # pre-process and normalize list to make resource generation easier. goes in 2 phases:
  #
  # phase 1: normalize/filter out bad data. some values may be json-encoded
  # since compact() only works with string values
  metric_alarms_prep = { for key, alarm in var.metric_alarms:
  key => merge(alarm, {
    # isolate expressions
    query_expressions = compact(flatten([
    for i, met in lookup(alarm, "metrics"): [
      lookup(met, "expression", null) == null ?
      null : jsonencode(merge(met, lookup(met, "metadata", {}))) ]
    ]))

    # isolate cloudwatch metrics
    query_metrics = compact(flatten([
    for i, met in lookup(alarm, "metrics"): [
      lookup(met, "expression", null) == null ?
      jsonencode(merge(met, lookup(met, "metadata", {}))) : null ]
    ]))
  })
  }

  # phase 2: unencode json-encoded values
  metric_alarms = { for key, alarm in local.metric_alarms_prep:
  key => merge(alarm, {
    query_expressions = [ for metjson in lookup(alarm, "query_expressions"): jsondecode(metjson) ]
    query_metrics     = [ for metjson in lookup(alarm, "query_metrics"): jsondecode(metjson) ]
  })
  }

  # repeat above but with anomaly alarms
  anomaly_alarms_prep = { for key, alarm in var.anomaly_alarms:
  key => merge(alarm, {
    query_expressions = compact(flatten([
    for i, met in lookup(alarm, "metrics"): [
      lookup(met, "expression", null) == null ?
      null: jsonencode(merge(met, lookup(met, "metadata"))) ]
    ]))

    query_metrics = compact(flatten([
    for i, met in lookup(alarm, "metrics"): [
      lookup(met, "expression", null)  == null ?
      jsonencode(merge(met, lookup(met, "metadata"))) : null ]
    ]))
  })
  }

  anomaly_alarms = { for key, alarm in local.anomaly_alarms_prep:
  key => merge(alarm, {
    query_expressions = [ for metjson in lookup(alarm, "query_expressions"): jsondecode(metjson) ]
    query_metrics     = [ for metjson in lookup(alarm, "query_metrics"): jsondecode(metjson) ]
  })
  }
}

# terraform can't conditionally output an attribute (e.g. if var.has_key { att1 = 1 } else { att2 = 2 })
# so, we need 2 separate alarm values to output either `threshold` (metric) or
# `threshold_metric_id` (anomaly).

resource "aws_cloudwatch_metric_alarm" "metric_alarms" {
  for_each          = local.metric_alarms
  alarm_name        = each.value["name"]
  alarm_description = lookup(each.value, "description", "")

  evaluation_periods  = tostring(each.value["breaches"])
  comparison_operator = local.OPERATOR_MAP[ each.value["operator"] ]
  threshold           = tostring(each.value["threshold"])

  alarm_actions             = lookup(each.value, "alarm_actions", [ ])
  ok_actions                = lookup(each.value, "ok_actions", [ ])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [ ])

  dynamic "metric_query" {
    for_each = { for i, v in lookup(each.value, "query_expressions"): i => v }
    content {
      id          = metric_query.value["id"]
      expression  = metric_query.value["expression"]
      return_data = each.value["return_data_on_id"] == metric_query.value["id"]
    }
  }

  dynamic "metric_query" {
    for_each = { for i, v in lookup(each.value, "query_metrics"): i => v }
    content {
      id          = metric_query.value["id"]
      return_data = each.value["return_data_on_id"] == metric_query.value["id"]
      metric {
        namespace   = metric_query.value["namespace"]
        metric_name = metric_query.value["metric"]
        dimensions  = lookup(metric_query.value, "dimensions", {})
        period      = each.value["period"]
        stat        = lookup(metric_query.value, "statistic", "Sum")
        unit        = lookup(metric_query.value, "unit", null)
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "anomaly_alarms" {
  for_each          = local.anomaly_alarms
  alarm_name        = each.value["name"]
  alarm_description = lookup(each.value, "description", "")

  evaluation_periods  = tostring(each.value["breaches"])
  comparison_operator = local.ANOMALY_OPERATOR_MAP[ each.value["operator"] ]
  threshold_metric_id = each.value["threshold_metric_id"]

  alarm_actions             = lookup(each.value, "alarm_actions", [ ])
  ok_actions                = lookup(each.value, "ok_actions", [ ])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [ ])

  dynamic "metric_query" {
    for_each = { for i, v in each.value["query_expressions"]: i => v }
    content {
      id          = metric_query.value["id"]
      expression  = metric_query.value["expression"]
      return_data = each.value["threshold_metric_id"] == metric_query.value["id"]
    }
  }

  dynamic "metric_query" {
    for_each = { for i, v in each.value["query_metrics"]: i => v }
    content {
      id          = metric_query.value["id"]
      return_data = each.value["threshold_metric_id"] == metric_query.value["id"]
      metric {
        namespace   = metric_query.value["namespace"]
        metric_name = metric_query.value["metric"]
        dimensions  = lookup(metric_query.value, "dimensions", {})
        period      = each.value["period"]
        stat        = lookup(metric_query.value, "statistic", "Sum")
        unit        = lookup(metric_query.value, "unit", null)
      }
    }
  }
}
