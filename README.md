# LUKS Mount Bash Function

Version 8 - Now with keyfile support


# PURPOSE

Simple bash function to quickly mount and unmount LUKS images from the command line. Typing a single line in the terminal finds available LUKS containers and mounts to your specified destination directory. Keyfiles are supported.

The purpose is to make mounting and unmounting LUKS containers more convenient, without typing the long flags and options after each cryptsetup command.

Only LUKS file containers / images can be mounted (.bin). **Partitions are NOT supported**. Function can mount multiple LUKS file containers.

# SYSTEM REQUIREMENTS

The only requirements are systems with hardware to support modern encryption and decryption, cryptsetup and associated packages, and running in a debian-based environment (ubuntu, mint, popOS, debian etc).

Android / iOS are not supported even if you can run cryptsetup. These distro are severely locked-down so mounting containers in userspace (FUSE) is basically not possible without gaining root access to the device.

# INSTALLATION

Add these entries to your **.bashrc** in your home directory with your favorite text editor:

    # ANSI colors
    WHITE="\e[97m"
    BLACK="\e[30m"
    GRAY="\e[90m"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[34m"
    MAGENTA="\e[35m"
    CYAN="\e[36m"
    RESET="\e[0m"

    # Load bash functions
    if [ -f ~/.bash_functions ]; then
        . ~/.bash_functions
    fi

Also add the following to your **.bash_aliases** in your home directory. Create aliases file if it does not exist (eg. nano ~/.bash_aliases):

    aliases cont-open='cont'
    aliases cont-close='cont_close'

Finally, copy **.bash_functions** file to your home directory. Make executable and register in bash:

    cp .bash_functions ~
    chmod +x .bash_functions
    source ~/.bashrc

# USEAGE

Use the following syntax in your terminal.
To open a LUKS image:

    cont-open (container dir) (mount dir)


To close a LUKS image:

    cont-close (container alias)

Note:
1. **You do not have to specify the path to the container itself, only to it's location directory**. The bash function will automatically display a list of available containers to mount.

2. Keyfiles are auto-loaded from the same path as the container using the .keyfile file extension (eg. luks-container.keyfile). The bash function will ask for a custom path if keyfile is not found.

# DISCLAIMER

Please review this bash function carefully. NEVER run  scripts blindly without understanding what it could do. Don't trust me. Google around to find out more. Please research, research, research.

# LEGAL

Please note that by downloading and running this bash function you acknowledge that 
I am not responsible or liable for any damages or losses arising from your use or inability to use the script and or software used under this script. You are solely responsible for your use of this script. If you harm someone or get into a dispute with a 3rd party, you consent to me waiving any involvement.
