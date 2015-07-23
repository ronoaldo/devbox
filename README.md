# Development Box on Google Cloud

Quick setup an Open Source Cloud IDE on Google Cloud Platform
with Debian Jessie and Codebox!

## Quick start

* Install the Google Cloud SDK (https://cloud.google.com/sdk) on your computer
* Run the following command

```
    gcloud compute instances create \
        --no-boot-disk-auto-delete \
        --metadata-from-file startup-script=startup.sh \
        --metadata codebox-password=PASSWORD \
        --tags http-server,devbox \
        --image beta-debian-8-jessie-v20150710 \
        --image-project debian-cloud \
        --zone ZONE \
        INSTANCE
```

Replacing:

* *PASSWORD* with your own password to login in the IDE
* *INSTANCE* with the name of the instance that will be created
* *ZONE* with the compute engine Zone you want your box to run

Wait for a few minutes until the box is ready. You can check the instance
is ready using the command:

```
    gcloud compute instances get-serial-port-output \
        --zone ZONE INSTANCE 
```

If all commands were executed you should see a message saying that the box is ready.
If you forgot to specify a password with the metadata key _codebox-password_
a random password is generated for you, and is available at the console output.

## Tips and Tricks

### Separate data disk for $HOME

It is desirable to have a separated data disk attached to your
box to keep your files safe. The startup script is prepared
to recognize a metadata entry with key _codebox-datadisk_,
containing the name of a Persistent Disk attached to your
instance. When this entry is detected, and the disk
is attached to the instance during boot, the script will
mount the disk as the `home` partition.

To create a new SSD disk to host your partition you can
run the commands:

```
    gcloud compute disks create \
        --zone ZONE \
        --type pd-ssd \
        --size 30 \
        DISK_NAME
```

Replacing:
* *ZONE*: with the same compute engine Zone where your instance runs
* *DISK_NAME*: with the name of your disk

In the sample bellow, we are creating an SSD disk, but
you can also create a standard disk with lower performance
and costs by using the value _pd-standard_ for the _--type_
parameter.

After you create the disk, you can now launch yor box with
the following command to use the disk to store your data:

```
    gcloud compute instances create \
        --disk name=DISK_NAME,device-name=DISK_NAME \
        --metadata-from-file startup-script=startup.sh \
        --metadata codebox-password=PASSWORD,codebox-datadisk=DISK_NAME \
        --tags http-server,devbox \
        --image beta-debian-8-jessie-v20150710 \
        --image-project debian-cloud \
        --zone ZONE \
        INSTANCE
```

This is essentially the same command as before, but with the parameters
`--disks name=DISK_NAME device-name=DISK_NAME` and `--metadata codebox-datadisk=DISK_NAME`
added to the gcloud options.

### Manage costs

The first thing to do is to take into account the Instance Type.
The instance launched by default is the `n1-standard-1` which
is a good balance of cost, memory and CPU allocated.
If your development workload is very low, you can lower that to
`f1-micro` and `g1-small` to make more savings. You can also
choose a high memory or high CPU instance types if you need one of
those items more than the other.

Google Compute Engine offers the Sustained Usage Discount
pricing advantage, so if you want to keep your instance aways
up you will be billed by a lower hourly rate. However, if you
use your box less than 50% of the montly time, it is better
to turn it off when you're done, and boot it up again
to get back to work. This way you can save the ammount
not in use per month. The sustained discount usage maximum
discount is around 30%, so if you use your VM for, say, 70%
of the month, just leave it up all time and you will take
advantage of that.

### Security

Choose a strong password and keep an eye on the security updates
from Debian and Codebox. Codebox is a Node app and currently
is not package as part of Debian, so it is important to keep
an eye on their updates.

Also, you can change the startup script nginx template to use
an SSL certificate to encrypt your connection, either by purchasing
an SSL for your domain or using a self-signed certificate.