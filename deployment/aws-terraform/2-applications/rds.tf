resource "aws_sns_topic" "global" {
  name = "globalNotifications-Azavea-${var.environment}"
}

resource "aws_db_subnet_group" "default" {
  name        = var.rds_database_identifier
  description = "Private subnets for the RDS instances"
  subnet_ids  = module.eks.vpc_private_subnet_ids

  tags = {
    Name    = "dbsngDatabaseServer"
    Project = "azavea-${var.environment}"
  }
}

resource "aws_db_parameter_group" "default" {
  name_prefix = var.rds_database_identifier
  description = "Parameter group for the RDS instances"
  family      = var.rds_parameter_group_family

  parameter {
    name  = "log_min_duration_statement"
    value = var.rds_log_min_duration_statement
  }

  parameter {
    name  = "log_connections"
    value = var.rds_log_connections
  }

  parameter {
    name  = "log_disconnections"
    value = var.rds_log_disconnections
  }

  parameter {
    name  = "log_lock_waits"
    value = var.rds_log_lock_waits
  }

  parameter {
    name  = "log_temp_files"
    value = var.rds_log_temp_files
  }

  parameter {
    name  = "log_autovacuum_min_duration"
    value = var.rds_log_autovacuum_min_duration
  }

  tags = {
    Name    = "dbpgDatabaseServer"
    Project = "azavea-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "database" {
  source = "github.com/azavea/terraform-aws-postgresql-rds?ref=3.0.0"

  vpc_id                     = module.eks.vpc_id
  allocated_storage          = var.rds_allocated_storage
  engine_version             = var.rds_engine_version
  instance_type              = var.rds_instance_type
  storage_type               = var.rds_storage_type
  database_identifier        = var.rds_database_identifier
  database_name              = var.rds_database_name
  database_username          = var.rds_database_username
  database_password          = var.rds_database_password
  backup_retention_period    = var.rds_backup_retention_period
  backup_window              = var.rds_backup_window
  maintenance_window         = var.rds_maintenance_window
  auto_minor_version_upgrade = var.rds_auto_minor_version_upgrade
  final_snapshot_identifier  = var.rds_final_snapshot_identifier
  skip_final_snapshot        = var.rds_skip_final_snapshot
  copy_tags_to_snapshot      = var.rds_copy_tags_to_snapshot
  multi_availability_zone    = var.rds_multi_az
  storage_encrypted          = var.rds_storage_encrypted
  subnet_group               = aws_db_subnet_group.default.name
  parameter_group            = aws_db_parameter_group.default.name
  deletion_protection        = var.rds_deletion_protection

  alarm_cpu_threshold                = var.rds_cpu_threshold_percent
  alarm_disk_queue_threshold         = var.rds_disk_queue_threshold
  alarm_free_disk_threshold          = var.rds_free_disk_threshold_bytes
  alarm_free_memory_threshold        = var.rds_free_memory_threshold_bytes
  alarm_cpu_credit_balance_threshold = var.rds_cpu_credit_balance_threshold
  alarm_actions                      = [aws_sns_topic.global.arn]
  ok_actions                         = [aws_sns_topic.global.arn]
  insufficient_data_actions          = [aws_sns_topic.global.arn]

  project     = "azavea-kubernetes"
  environment = var.environment
}

resource "aws_security_group_rule" "rds_node_access" {
  type = "ingress"
  from_port = 0
  to_port = module.database.port
  protocol = "tcp"
  source_security_group_id = module.eks.cluster_security_group
  security_group_id = module.database.database_security_group_id
}
