# Metrics, Dashboards, and Alarms

This module streamlines the dashboard and alarm creation process by defining your metrics once so that you can plug them into dashboard and alarm definitions.

## Metrics

Metrics are either an expression or a CloudWatch datapoint:

| `attribute` (req)    | type        | description                                | target     |
|----------------------|-------------|--------------------------------------------|------------|
| `id` **req**         | string      |                                            | both       |
| `expression` **req** | string      |                                            | expression |
| `namespace` **req**  | string      |                                            | cloudwatch |
| `metric` **req**     | string      |                                            | cloudwatch |
| `statistic`          | string      | defaults to `Sum`                          | cloudwatch |
| `dimensions`         | map(string) |                                            | cloudwatch |
| `metadata`           | map(any)    | properties to pass to dashboard definition | both       |

## Alarms

Alarms are distinguished as being either non-anomaly (`metric_alarms`) or anomaly (`anomaly_alarms`) and are nearly identical in definition:

| `attribute` (req)             | type        | description                                          | target      |
|-------------------------------|-------------|------------------------------------------------------|-------------|
| `name` **req**                | string      | alarm name                                           | both        |
| `description`                 | string      | alarm description                                    | both        |
| `metrics` **req**             | metric[]    | 1 or more metric definitions                         | both        |
| `period` **req**              | number      |                                                      | both        |
| `breaches` **req**            | number      | how many consecutive threshold triggers before alarm | both        |
| `operator` **req**            | string      | `<`, `<=`, `>`, `>=`                                 | non-anomaly |
|                               |             | `<`, `>`, `<>`                                       | anomaly     |
| `threshold` **req**           | number      |                                                      | non-anomaly |
| `return_data_on_id` **req**   | string      | which metric will provide the threshold value        | non-anomaly |
| `threshold_metric_id` **req** | string      | which metric provides the anomaly value              | anomaly     |
| `alarm_actions`               | string[]    |                                                      | both        |
| `ok_actions`                  | string[]    |                                                      | both        |
| `insufficient_data_actions`   | string[]    |                                                      | both        |
| `tags`                        | map(string) |                                                      | both        |

## Dashboards & Widgets

Each dashboard is just a collection of widgets. Currently, the widgets are limited to showing metrics (i.e. there isn't yet support for text-based widgets):

### Dashboard

| `attribute` (req) | type     | description                  |
|-------------------|----------|------------------------------|
| `name` **req**    | string   |                              |
| `widgets` **req** | widget[] | a list of widget definitions |

### Widget

Widgets are plotted on a grid with 24 vertical units. Widgets can be as narrow as 1 or as wide as 24.

| `attribute` (req)    | type     | description                             |
|----------------------|----------|-----------------------------------------|
| `x` **req**          | number   | The X-coordinate ranging from `[0, 24)` |
| `y` **req**          | number   | The Y-coordinate                        |
| `width` **req**      | number   | between `[1, 24]`                       |
| `height` **req**     | number   |                                         |
| `metrics` **req**    | metric[] |                                         |
| `properties` **req** | map(any) |                                         |
| — `.title` **req**   | string   |                                         |
| — `.stacked` **req** | boolean  |                                         |
| — `.period` **req**  | number   |                                         |
| — `.region` **req**  | string   |                                         |

## How to Use

To keep dashboard and alarm creation in sync and sane, let's abstract our core metrics so that we can plug them back in to our definitions. We'll start by defining metrics in groups:

```hcl-terraform
locals {
  metrics = {
    group1 = [
        {
            id = 'someaction_exceeded'
            namespace = 'Metric/NS'
            metric = 'SomeAction'
            statistic = "SampleCount"
            # optional
            dimensions = {
              Dimension1 = 'Value'
            }
            metadata = {}
        },
        {
            id = 'expression'
            expression = 'someaction_exceeded / 100'        
        },
        {
            id = 'anomaly'
            expression = 'ANOMALY_DETECTION_BAND(someaction_exceeded, 2)'
        } 
    ]
  }
}
```

> `metadata` is a map that will be used in the dashboard widget -- [read more about the supported properties](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/CloudWatch-Dashboard-Body-Structure.html#CloudWatch-Dashboard-Properties-Metric-Widget-Object).  

In the real world, you might have a group of metrics that deal with HTTP requests, another group that deals with DB statistics, and yet another to monitor an ECS container.

Now that we have our groups, we can define a dashboard and a couple of different alarms:

```hcl-terraform
module "dashboard_alarm" {
    source  = "./module"
    dashboards = {
      "sla" = {
        name    = "Dashboard-SLA"
        widgets = [
            {
                x          = 0.0
                y          = 0.0
                width      = 6.0
                height     = 6.0
                properties = {
                    title   = "HTTP Requests & 5XX Error Rate"
                    stacked = false
                    period  = 300
                    region  = local.region
                }
                metrics    = local.metrics.group1
            }
        ]      
      }     
    }
    
    # alarm based on non-anomaly value
    metric_alarms = {
      critical = {
        metrics = local.metrics.group1
        threshold = 100
        operator = ">"
        return_data_on_id = "expression"
        ...
      }    
    }
  
    # alarm based on anomaly value 
    anomaly_alarms = {
      critical = {
        metrics = local.metrics.group1
        threshold_metric_id = "anomaly"
        operator = "<>"
        ...
      }    
    }
}
```

Just like that, you've been able to use re-use the same set of metrics in 3 different ways, and they'll always be in sync with new changes.
