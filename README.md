# FTB Pyramid Reborn - OpenComputers code

This is the OpenComputers part of the logic for FTB's "Pyramid Reborn" 1.12.2 quest map.

## Updating

In general, end-user updates are preferably done by resetting the map with the version from the latest released modpack.

If you are a developer, here's a short set of commands to update the source code from Git and spread it across computers:

    # cd /home
    # wget https://raw.githubusercontent.com/ChenThread/octagon/master/oczip.lua
    # wget https://github.com/asiekierka/ftb-pyramid-reborn-oc/archive/master.zip
    # oczip master.zip

From there, copy results/ftb-pyramid-reborn-oc/* to the drive root. Finally, reboot the computer and restart the quest provisioning server.

## License

In general, the source code in this repository is licensed under the LGPLv3 license.

Certain source code files under home/ are derived from the [octagon](https://github.com/ChenThread/octagon/) project - those specific 
files can instead be used under the terms of the notices in each respective file.
