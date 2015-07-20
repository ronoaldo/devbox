# Development Box on Google Cloud

Quick setup an Open Source Cloud IDE with Google Cloud Platform,
Debian Jessie and Codebox IDE!

Quick start:

* Install the Google Cloud SDK (https://cloud.google.com/sdk)
* Run the following command:

    gcloud compute instances create \
        --metadata-from-file startup-script=startup.sh \
        --metadata codebox-password=<your password here> \
        --tags http-server \
        --image beta-debian-8-jessie-v20150710 \
        --image-project debian-cloud \
        <your box name here>

Replacing:

* *your password here* with your own password to login in the IDE
* *your box name here* with the name of the image that will be created

Wait for a few minutes until the box is ready and then open the IP
address associated with your instance from the Developers Console.
You will then be able to login and manage your projects from there.
