#!/bin/bash

# Variables
PROJECT="project_id"
ZONE="asia-east2-c"
VM_NAME="name-vm"
STATIC_IP_NAME="name-static-ip"   # Static IP Name
NEW_IMAGE_NAME="name-image"
NEW_MACHINE_TYPE="e2-small"
SSH_PORT=8734
SSH_KEYS="username:sshkey

# Authenticate using the JSON key file
echo "Authenticating with service account..."
gcloud auth activate-service-account --key-file="path/to/your/.json"

# Set the project
gcloud config set project "$PROJECT"

# Stop the existing instance (if running)
echo "Checking VM status..."
VM_STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="get(status)" --project="$PROJECT")

if [ "$VM_STATUS" != "TERMINATED" ]; then
  echo "Stopping VM: $VM_NAME..."
  gcloud compute instances stop "$VM_NAME" --zone="$ZONE" --project="$PROJECT"
fi

# Release the static IP if it is in use by the VM
echo "Checking if Static IP is in use by VM $VM_NAME..."
STATIC_IP_STATUS=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="asia-east2" --format="value(status)" --project="$PROJECT")

if [ "$STATIC_IP_STATUS" == "IN_USE" ]; then
  echo "Releasing static IP..."
  gcloud compute instances delete-access-config "$VM_NAME" --zone="$ZONE" --access-config-name="External NAT" --project="$PROJECT"
  echo "Waiting for static IP release..."
  sleep 60
else
  echo "Static IP is not in use."
fi

# Find the latest snapshot
echo "Fetching latest snapshot..."
LATEST_SNAPSHOT=$(gcloud compute snapshots list \
  --filter="name~^$VM_NAME-.* AND status=READY" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)" \
  --project="$PROJECT")

if [ -z "$LATEST_SNAPSHOT" ]; then
  echo "No snapshot found. Exiting."
  exit 1
fi
echo "Latest snapshot: $LATEST_SNAPSHOT"

# Use the exact snapshot name as the new VM name
NEW_VM_NAME="$LATEST_SNAPSHOT"
NEW_VM_NAME=${NEW_VM_NAME:0:63}  # Ensure the name is within the 63-character limit
echo "New VM name: $NEW_VM_NAME"

# Create a new image from the latest snapshot
echo "Creating new image: $NEW_IMAGE_NAME..."
gcloud compute images create "$NEW_IMAGE_NAME" \
  --source-snapshot="$LATEST_SNAPSHOT" \
  --storage-location="asia-east2" \
  --labels="goog-terraform-provisioned=true" \
  --project="$PROJECT"

# Get the static IP by name
STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --region="asia-east2" --format="value(address)" --project="$PROJECT")

if [ -z "$STATIC_IP" ]; then
  echo "Static IP $STATIC_IP_NAME not found. Exiting."
  exit 1
fi
echo "Found static IP: $STATIC_IP"

# Create a new VM instance with the exact snapshot name
echo "Creating new VM instance..."
gcloud compute instances create "$NEW_VM_NAME" \
  --zone="$ZONE" \
  --machine-type="$NEW_MACHINE_TYPE" \
  --boot-disk-size="10GB" \
  --boot-disk-type="pd-balanced" \
  --boot-disk-device-name="$NEW_VM_NAME-disk" \
  --image="$NEW_IMAGE_NAME" \
  --tags="innovehealth" \
  --metadata=startup-script="#!/bin/bash
sed -i 's/^#Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config
ufw allow $SSH_PORT/tcp
systemctl restart sshd" \
  --metadata-from-file=ssh-keys=<(echo "$SSH_KEYS") \
  --address="$STATIC_IP" \
  --project="$PROJECT"

echo "VM creation complete."
