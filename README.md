# LUKS Mount Bash Function

Version 8 - Now with keyfile support


# PURPOSE

Simple bash function to quickly mount and unmount LUKS images from the command line. A single terminal line finds available LUKS containers and mounts to your specified destination directory. Key files are supported.

The purpose is to make mounting and unmounting LUKS containers more convenient, without typing the long flags and options after each cryptsetup command.

Only LUKS file containers / images can be mounted by this function. **Block devices (partitions) are NOT supported**. Function can mount multiple LUKS file containers.

# SYSTEM REQUIREMENTS

The only requirements are systems with hardware to support modern encryption and decryption, cryptsetup and associated packages, and running in a debian-based environment (ubuntu, mint, popOS, debian etc.)

# INSTALLATION

Copy **.bash_functions** file to your home directory. Make executable and register file in bash:

    cp .bash_functions ~
    chmod +x .bash_functions
    source ~/.bash_functions


Add the following entries to your .bash_aliases in your home directory. Create aliases file if it does not exist (eg. nano ~/.bash_aliases):

    aliases cont-open='cont'
    aliases cont-close='cont_close'


To open a LUKS image:

    cont-open (container dir) (mount dir)


To close a LUKS image:

    cont-close (container alias)


1. **You do not have to specify the path to the container itself, only to it's location directory**. The bash function will automatically display a list of available containers to mount.

2. Keyfiles are auto-loaded from the same path as the container (eg. luks-container.keyfile). The bash function will ask for a custom path if keyfile is not found.

# DISCLAIMER

Please review this bash function carefully. NEVER run  script blindly without understanding what it could do. Don't trust me. Google around to find out more. Please research, research, research.

# LEGAL

Please note that by downloading and running this bash function you acknowledge that 
I am not responsible or liable for any damages or losses arising from your use or inability to use the script and or software used under this script. You are solely responsible for your use of this script. If you harm someone or get into a dispute with a 3rd party, you consent to me waiving any involvement.
