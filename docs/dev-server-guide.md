# 🏗 Dev Server Guide

**Although the below information can be found online, we've compiled it here for your convenience.**

This guide will help you setup a dedicated server for development purposes. This is useful if you want to test whether your changes work in a multiplayer environment, or if you want to test the server performance.

In this guide you'll find instructions on how to:

1. Install SteamCMD
2. Install the Garry's Mod Dedicated Server software
3. Clone the Versus Addon and link it into the garrysmod server directory
4. Start the server

Additionally you should consider this for a production server:

* (Recommended) Authenticate your server
* (Optional) Enable MySQL

## Step-by-Step Guide

1. Follow these instructions to install SteamCMD:
    * [Linux](https://developer.valvesoftware.com/wiki/SteamCMD#Linux)
    * [Windows](https://developer.valvesoftware.com/wiki/SteamCMD#Windows)

2. Install the Garry's Mod Dedicated Server software using SteamCMD:

    ```sh
    steamcmd +login anonymous +force_install_dir /path/to/gmod +app_update 4020 validate +quit
    ```

    *Replace `/path/to/gmod` with the path to where you want to install the server.*

    *Replace `steamcmd` with the path to the SteamCMD executable on Windows (e.g: C:\steamcmd.exe)*

3. Clone this repository somewhere on your computer (not in the `garrysmod/` directory) and ensure the directory is named `versus`:

    ```sh
    git clone https://github.com/luttje/gmod-versus versus
    ```

4. Navigate to the Garry's Mod server's `garrysmod/addons` directory:

    ```sh
    cd /path/to/gmod/garrysmod/addons
    ```

5. Create a symbolic link to the `addon` directory of this repository:

    ```sh
    ln -s /path/to/versus/addon versus
    ```

     *Replace `/path/to/versus` with the path to the cloned repository on your computer.*

6. (Optional) If you have content other than the default content you will want to create a Workshop Collection for your server, following [the instructions on the official Garry's Mod documentation](https://wiki.facepunch.com/gmod/Workshop_for_Dedicated_Servers). When creating the collection **make note of the collection ID, you'll need it later.**

7. Start the server so you can test it. Run the following server start command:

    ```bash
    /path/to/gmod/srcds -console -game garrysmod -tickrate 100 +maxplayers 64 +gamemode versus +map exp_c18_v1_alpha034 +host_workshop_collection 3674693854
    ```

    *Replace `3674693854` with the ID of the Workshop Collection you created. You can use `3674693854` for the default content and `exp_c18_v1_alpha034` map*

8. Open Garry's Mod and connect to the server by typing `connect <server ip>:27015` in the console. Replace `<server-ip>` with the IP of the server:

    * If the server is remote you have to use the public IP (which is listed towards the end of the server start output) and ensure the port is open in the firewall.

    * If the server is local you have to use the `Network IP` which is listed in the server start output directly after:

      ```bash
      Changing gamemode to Versus (versus)
      Network: IP 192.168.x.x, mode MP, dedicated Yes, ports 27015 SV / 27005 CL
      ```

9. To easily start the server with the required command line arguments we use a `start-srcds.bat` and `start-srcds.sh` for Windows and Linux respectively. These scripts are located in [the `tools/dev` directory of this project](../tools/dev).

### Authenticating your server (Recommended)

Next you'll want to generate a GLST login token for your server. This is required to authenticate your server and have it show up in the server browser. You can [generate a token here](https://steamcommunity.com/dev/managegameservers):

1. Enter App ID `4000` (Garry's Mod)

2. Choose any name so you can identify the token later (e.g: `My Versus Server`)

3. Click "Create"

4. From now on start the server by adding the following to the server start command:

    ```bash
    +sv_setsteamaccount <glst-token>
    ```

    *Replace `<glst-token>` with the token you generated.*
