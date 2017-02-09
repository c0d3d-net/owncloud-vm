# owncloud-vm
Scripts to setup and configure the ownCloud VM.

Feel free to contribute!

----------------------------------------------------------------------------------------------------------------------------

### **DOWNLOAD THE VM**

**You can find all the VMs [here](https://www.techandme.se/pre-configured-owncloud-installaton/).**

----------------------------------------------------------------------------------------------------------------------------

#### CHANING DEFAULT USER ($UNIXUSER)

If you want to change the default user to your own, you have to change $UNIXUSER in four places:

- owncloud_install(_production).sh
- change-ocadmin-profile.sh
- owncloud-startup-script.sh
- rc.local (for the beta VM)

#### HOW TO SETUP THE BETA VM (PRE-PRODUCTION)

- Create a clean Ubuntu Server 16.04 VM with VMware Workstation or VirtualBox
- Edit rc.local likes this:

```
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Get a fresh RC.LOCAL
    if [ -f /var/rc.local ];
    then
        echo "rc.local exists"
    else
        wget https://raw.githubusercontent.com/techandme/owncloud-vm/master/beta/rc.local -P /var/
        cat /var/rc.local > /etc/rc.local
        rm /var/rc.local
        reboot
    fi

exit 0
```
- Reboot

----------------------------------------------------------------------------------------------------------------------------

### TEST A DEMO VERSION

You can test ownCloud [here](https://demo.owncloud.org/).

----------------------------------------------------------------------------------------------------------------------------
*Send me an email if you have any questions: daniel [a] techandme.se*
*You can also join our [IRC channel](https://irc.techandme.se/)*
