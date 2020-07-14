locals {
  dashboards = var.dashboards == null ? {} : var.dashboards
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  for_each       = local.dashboards
  dashboard_name = lookup(each.value, "name")

  # cloudwatch hates null values in map, so we need to strip them out of JSON
  # (tf doesn't have a function to remove null elements from maps)
  dashboard_body = replace(jsonencode({
    widgets = [
    for widget in lookup(each.value, "widgets", [ ]):
    {
      type       = "metric"
      x          = lookup(widget, "x")
      y          = lookup(widget, "y")
      width      = lookup(widget, "width")
      height     = lookup(widget, "height")
      properties = merge(lookup(widget, "properties", {}), {
        # converting the dimensions key-value map into a list of alternating
        # key & value elements requires us to
        #
        # 1. build a list of `[key, value]` elements - `[ ["k1", "v1"], ["k2", "v2"] ]`
        # 2. flatten to a list of strings - `["k1", "v1", "k2", "v2"]`
        #
        # ultimately need to product one of the following lists:
        #
        # 1. `[ { ... } ]` (used for an expression)
        # 2. `[ "namespace", "metric", "k1", "v1", ..., {...} ]` (used for cloudwatch metric)
        #
        # @formatter:off
        metrics = [ for metric in lookup(widget, "metrics", [ ]):
        flatten(concat([
          # for expressions, these would produce `["", ""]`, which can be reduced to []
          compact([
            lookup(metric, "namespace", ""),
            lookup(metric, "metric", "")
          ]),
          flatten([ for key, val in lookup(metric, "dimensions", {}): [ key, val ] ]),
          # auto-inject id and expression for metric properties
          # for stat, we basically set as follows: metadata.stat, metric.statistic, null (defer to properties.stat)
          [ merge(
          #                { stat = lookup(metric, "statistic", null) },
          lookup(metric, "metadata", {}),
          {
            id         = lookup(metric, "id")
            expression = lookup(metric, "expression", null)
          }
          ) ]
        ]))
        ]
        # @formatter:on
      })
    }
    ]
  }), "/\"[^\"]+\":null,?/", "")
}
