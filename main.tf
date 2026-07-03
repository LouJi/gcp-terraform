# 1. PROVIDER & VARIABLE CONFIGURATION

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

variable "project_id" {
  type        = string
  description = "The GCP Project ID where resources will be deployed"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

# 2. SECURITY: SERVICE ACCOUNT & IAM ROLES

# Create the custom service account for the VM
resource "google_service_account" "vm_sa" {
  account_id   = "app-instance-sa"
  display_name = "Service Account for App Engine VMs"
}

# Grant the Service Account "Storage Object Viewer" role on the specific bucket
resource "google_storage_bucket_iam_member" "sa_storage_viewer" {
  bucket = google_storage_bucket.app_storage.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vm_sa.email}"
}

# 3. STORAGE: GCS BUCKET

resource "google_storage_bucket" "app_storage" {
  name                        = "${var.project_id}-app-assets-bucket"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  # Prevents accidental deletion of the bucket via Terraform
  lifecycle {
    prevent_destroy = false 
  }
}


# 4. COMPUTE: INSTANCE & TARGET POOL

# The virtual machine instance
resource "google_compute_instance" "app_server" {
  name         = "web-app-server"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP to allow traffic from the load balancer
    }
  }

  # Attach the custom service account to the VM
  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Simple metadata startup script to verify it's up
  metadata_startup_script = "echo 'Hello from Terraform' > /var/www/html/index.html"
}

# Group the instance into a Target Pool for the Load Balancer
resource "google_compute_target_pool" "app_pool" {
  name = "app-target-pool"

  instances = [
    google_compute_instance.app_server.self_link
  ]

  health_checks = [
    google_compute_http_health_check.app_health.name
  ]
}


# 5. NETWORKING: LOAD BALANCER & HEALTH CHECK

# HTTP Health Check to monitor VM status
resource "google_compute_http_health_check" "app_health" {
  name               = "app-http-health-check"
  request_path       = "/"
  check_interval_sec = 5
  timeout_sec        = 5
}

# Forwarding rule acts as the frontend entry point of the Load Balancer
resource "google_compute_forwarding_rule" "lb_frontend" {
  name                  = "app-lb-forwarding-rule"
  region                = var.region
  port_range            = "80"
  target                = google_compute_target_pool.app_pool.id
  load_balancing_scheme = "EXTERNAL"
}


# OUTPUTS
#For testing purpose 

output "load_balancer_ip" {
  value       = google_compute_forwarding_rule.lb_frontend.ip_address
  description = "The external IP address of your load balancer"
}

