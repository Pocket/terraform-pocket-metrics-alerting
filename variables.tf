variable "dashboards" {
	type = any
	default = {}
	description = "A map of dashboard definitions. See README.md ('Dashboards') for more information. (Unfortunately, Terraform's weird type system makes it impossible to even partially define the structure here.)"
}

variable "metric_alarms" {
	type = any
	default = {}
	description = "A map of maps with each item being a metric alarm. See README.md ('Alarms') for more information. (Unfortunately, Terraform's weird type system makes it impossible to even partially define the structure here.)"
}

variable "anomaly_alarms" {
	type = any
	default = {}
	description = "A map of maps with each item being an anomaly alarm. See README.md ('Alarms') for more information. (Unfortunately, Terraform's weird type system makes it impossible to even partially define the structure here.)"
}
