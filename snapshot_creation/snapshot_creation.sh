#!/bin/bash

# Set the timezone to Philippine time (UTC+8)
export TZ=Asia/Manila

# Variables
PROJECT_ID="Project_ID"  # project ID
ZONE="asia-east2-c"
REGION="asia-east2"
DATE=$(date +%Y%m%d)
SNAPSHOT_SCHEDULE_NAME="snapshot-schedule-$DATE"
DISK_NAME="name-vm"  # Disk name

# Calculate the start time for Friday at 16:00 in Philippine Time
START_TIME_PHT="16:00"
START_TIME_UTC="08:00" 

# Display the calculated start time in UTC (on Friday in PHT is 08:00 on Friday UTC)
echo "Scheduled snapshot start time: $START_TIME_UTC UTC (Friday 16:00 PHT)"

# Set the project for the gcloud command
gcloud config set project $PROJECT_ID

# Create the snapshot schedule
echo "Creating Snapshot Schedule for disk $DISK_NAME in region $REGION..."
gcloud compute resource-policies create snapshot-schedule $SNAPSHOT_SCHEDULE_NAME \
    --start-time="$START_TIME_UTC" \
    --weekly-schedule=friday \
    --max-retention-days=14 \
    --region="$REGION" \
    --storage-location="$REGION"

if [ $? -eq 0 ]; then
    echo "Snapshot schedule created successfully."
else
    echo "Failed to create snapshot schedule."
    exit 1
fi

# Associate the disk with the snapshot schedule
gcloud compute disks add-resource-policies $DISK_NAME \
    --zone=$ZONE \
    --resource-policies=$SNAPSHOT_SCHEDULE_NAME

if [ $? -eq 0 ]; then
    echo "Disk successfully associated with snapshot schedule."
else
    echo "Failed to associate disk with snapshot schedule."
    exit 1
fi

echo "Script completed successfully."
