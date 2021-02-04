# VPC for all services
resource "aiven_project_vpc" "vpc" {
  project      = aiven_project.omega.project
  cloud_name   = var.location
  network_cidr = "10.0.0.0/24"

  timeouts {
    create = "5m"
  }
}

# Kafka service
resource "aiven_service" "kf" {
  project                 = aiven_project.omega.project
  cloud_name              = var.location
  project_vpc_id          = aiven_project_vpc.vpc.id
  plan                    = "business-8"
  service_name            = "${var.resource_prefix}-kf"
  service_type            = "kafka"
  maintenance_window_dow  = "monday"
  maintenance_window_time = "10:00:00"

  kafka_user_config {
    kafka_connect = true
    kafka_rest    = true
    kafka_version = "2.7"

    kafka {
      group_max_session_timeout_ms = 70000
      log_retention_bytes          = 1000000000
      auto_create_topics_enable    = false
    }
  }
}

# Topic for Kafka
resource "aiven_kafka_topic" "ingest_example" {
  project         = aiven_project.omega.project
  service_name    = aiven_service.kf.service_name
  topic_name      = "ingest_example"
  partitions      = 3
  replication     = 2
}

# Elasticsearch service
resource "aiven_service" "es" {
  project                 = aiven_project.omega.project
  cloud_name              = var.location
  project_vpc_id          = aiven_project_vpc.vpc.id
  plan                    = "business-32"
  service_name            = "${var.resource_prefix}-es"
  service_type            = "elasticsearch"
  maintenance_window_dow  = "monday"
  maintenance_window_time = "10:00:00"

  elasticsearch_user_config {
    elasticsearch_version = "7"
  }
}

# Connector from Kafka to Elasticsearch
resource "aiven_kafka_connector" "kf-es-conn" {
  project        = aiven_project.omega.project
  service_name   = aiven_service.kf.service_name
  depends_on     = [
    aiven_service.es,
    aiven_service.kf
  ]
  connector_name = "kf-es-conn"

  config = {
    "topics"                         = "ingest_example"
    "connector.class"                = "io.aiven.connect.elasticsearch.ElasticsearchSinkConnector"
    "type.name"                      = "es-connector"
    "name"                           = "kf-es-conn"
    "connection.url"                 = aiven_service.es.service_uri
    "key.converter"                  = "org.apache.kafka.connect.json.JsonConverter"
    "value.converter"                = "org.apache.kafka.connect.json.JsonConverter"
    "key.ignore"                     = "true"
    "schema.ignore"                  = "true"
    "value.converter.schemas.enable" = "false"
    "key.converter.schemas.enable"   = "false"
  }
}

# InfluxDB service
resource "aiven_service" "influx" {
  project                 = aiven_project.omega.project
  cloud_name              = var.location
  project_vpc_id          = aiven_project_vpc.vpc.id
  plan                    = "startup-4"
  service_name            = "${var.resource_prefix}-influx"
  service_type            = "influxdb"
  maintenance_window_dow  = "monday"
  maintenance_window_time = "11:00:00"
  influxdb_user_config {
    ip_filter = ["0.0.0.0/0"]
  }
}

# Send metrics from Kafka to InfluxDB
resource "aiven_service_integration" "kf_metrics" {
  project                  = aiven_project.omega.project
  integration_type         = "metrics"
  source_service_name      = aiven_service.kf.service_name
  destination_service_name = aiven_service.influx.service_name
}

# Send metrics from Elasticsearch to InfluxDB
resource "aiven_service_integration" "es_metrics" {
  project                  = aiven_project.omega.project
  integration_type         = "metrics"
  source_service_name      = aiven_service.es.service_name
  destination_service_name = aiven_service.influx.service_name
}

# Grafana service
resource "aiven_service" "grafana" {
  project        = aiven_project.omega.project
  cloud_name     = var.location
  project_vpc_id = aiven_project_vpc.vpc.id
  plan           = "startup-1"
  service_name   = "${var.resource_prefix}-grafana"
  service_type   = "grafana"
  grafana_user_config {
    ip_filter = ["0.0.0.0/0"]
  }	
}

# Dashboards for Kafka and Elasticsearch services
resource "aiven_service_integration" "dashboards" {
  project                  = aiven_project.omega.project
  integration_type         = "dashboard"
  source_service_name      = aiven_service.grafana.service_name
  destination_service_name = aiven_service.influx.service_name
  # Dashboard creation doesn't occur unless sources already exist
  depends_on = [
    aiven_service_integration.es_metrics,
    aiven_service_integration.kf_metrics
  ]
}