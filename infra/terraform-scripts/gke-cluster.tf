
variable "gcloud_key" {
  description = "Path to the GCP service account key file"
}

variable "gcp_project" {
  description = "GCP Project Name"
}

variable "gcp_region" {
  description = "GCP Region"
}

variable "k8s_cluster_name" {
  description = "Kubernetes Cluster Name"
}

variable "k8s_cluster_zone" {
  description = "Kubernetes Cluster Zone"
}

variable "k8s_node_type" {
  description = "Kubernetes Node Type"
}

variable "k8s_node_count" {
  description = "Kubernetes Node Count"
}

provider "google" {
  credentials = file(var.gcloud_key)
  project     = var.gcp_project
  region      = var.gcp_region
}

resource "google_container_cluster" "primary" {
  name     = var.k8s_cluster_name
  location = var.k8s_cluster_zone

  remove_default_node_pool = false
  initial_node_count = var.k8s_node_count

  node_config {
    machine_type = var.k8s_node_type
  }
}