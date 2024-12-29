provider "google" {
  credentials = file("path/to/your/.json")
  project     = "project_id"
  region      = "asia-east2"
}

# Step 1: Create an Instance using the Ubuntu 2204 LTS image (directly, no snapshot or custom image)
resource "google_compute_instance" "name_instance" {
  name         = "name-vm"
  machine_type = "e2-standard-2"
  zone         = "asia-east2-c"

  # Boot disk definition using the base Ubuntu 2204 image (without snapshot or custom image)
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ip.address  # Assign static IP to the VM
    }
  }

  tags = ["network_name"]

  metadata = {
    ssh-keys = <<-EOKEY
      username:your_sshkey
    EOKEY
  }

  # Startup script to change the SSH port to 8734 and open the port in the firewall
  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Change SSH port to 8734
    sed -i 's/^#Port 22/Port 8734/' /etc/ssh/sshd_config
    # Allow traffic on port 8734 through the firewall
    ufw allow 8734/tcp
    # Restart SSH service to apply changes
    systemctl restart sshd
  EOT
}

# Step 2: Firewall Rule for HTTP/HTTPS and Additional Ports (including 8734)
resource "google_compute_firewall" "name_firewall" {
  name    = "allow-specific-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8734", "8450"]
  }

  # Allow access from specified IP ranges (PLDT and Converge ICT)
  source_ranges = [
    "120.29.108.157/32", 
    "112.202.186.237/32",
    "103.16.0.0/16",   # Converge ICT
    "120.29.64.0/19",   # Converge ICT
    "122.54.0.0/16",    # Converge ICT
    "49.144.0.0/13",    # PLDT
    "124.6.128.0/17",   # PLDT
    "112.198.0.0/16"    # PLDT
  ]

  target_tags = ["network_name"]
}

# Optional: Health Check (Not necessary if no autoscaler)
resource "google_compute_health_check" "name_check" {
  name = "name-health-check"

  http_health_check {
    port = 80
  }
}

# Step 3: Reserve a static IP address
resource "google_compute_address" "static_ip" {
  name   = "name-static-ip"
  region = "asia-east2"  # Specify the region for the IP
}

# Output the static IP address of the instance
output "instance_ip" {
  value = google_compute_address.static_ip.address
}
