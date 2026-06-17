# LUKS Mount Bash Function

Bash function to mount and unmount LUKS images from the terminal. A single line finds available LUKS containers and mounts to your specified destination.

# PURPOSE

# SYSTEM REQUIREMENTS

# INSTALLATION

Copy .bash_functions file to your home directory. Make excutable and register file in bash:

cp .bash_functions ~

chmod +x .bash_functions

source ~/.bash_functions


Add the following entries to your .bash_aliases in your home directory. Create aliases file if it does not exist:

aliases cont-open='cont'

aliases cont-close='cont_close'


To open a LUKS image:


cont-open (container dir) (mount dir)


To close a LUKS image:


cont-close (container alias)


# DISCLAIMER

Please review the Debian 13 LiveCD/USB bootable OS build script carefully. NEVER run a script blindly without understanding what it could do. Don't trust me. Google around to find out more. Please research, research, research.

# LEGAL

Please note that by downloading and running this script you acknowledge that I am not responsible or liable for any damages or losses arising from your use or inability to use the script and or software used under this script. You are solely responsible for your use of this script. If you harm someone or get into a dispute with a 3rd party, you consent to me waiving any involvement.
