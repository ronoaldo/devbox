# Development Box on Google Cloud

Quick setup an Open Source Cloud IDE with Google Cloud Platform,
Debian Jessie and Codebox IDE!

Quick start:

* Install the Google Cloud SDK (https://cloud.google.com/sdk) on your computer
* Run the following command

```
    gcloud compute instances create \
        --metadata-from-file startup-script=startup.sh \
        --metadata codebox-password=<your password here> \
        --tags http-server \
        --image beta-debian-8-jessie-v20150710 \
        --image-project debian-cloud \
				--zone <choose a zone here> \
        <your box name here>
```

Replacing:

* *your password here* with your own password to login in the IDE
* *your box name here* with the name of the image that will be created
* *choose a zone here* with the compute engine Zone you want your box to run

Wait for a few minutes until the box is ready. You can check the instance
is ready using the command:

```
    gcloud compute instances get-serial-port-output \
        --zone <choose your zone here> <your box name here>
```

If all commands were executed you should see a message saying that the box is ready.
If you forgot to specify a password with the metadata key _codebox-password_
a random password is generated for you, and is available at the console output.