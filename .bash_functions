######################################################
# Bash function to mount an encrypted LUKS container #
# (launch with bash_aliases)                         #
# Multiple mounted containers supported              #
#                                                    #
# Syntax for opening and closing LUKS containters:   #
#   cont-open <container-dir> <mount-dir>            #
#   cont-close <container-alias>                     #
#                                                    #
# Keyfile support in container dir:                  #
#   <container-name.keyfile>                         #
######################################################

# v11 - Prompt for keyfile location (or skip)
# v10 - Added support for .key or .keyfile
# v9  - Correct ghost variables & bash syntax for cleaner code
# v7  - Added keyfile support
# v6  - improved finding luks container logic & readability

# ANSI colors variables
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"

# No Color (reset)
NC='\033[0m'

###########################
# Open container function #
###########################
cont() {
    # Position parameters
    CONT_PATH="$1"
    MOUNT_PATH="$2"

    # Correct usage check
    if [[ -z "${CONT_PATH}" || -z "${MOUNT_PATH}" ]]; then
        echo -e "${YELLOW}Usage:${NC} cont-open ${CYAN}<container-dir> <mount-point>${NC}\n"
        return 1
    else
        # Validate the container & mount paths
        if [[ ! -d "${CONT_PATH}" ]]; then
            echo -e "\n${RED}Error:${NC} ${CONT_PATH} is not a valid directory.\n" >&2
            return 1
        elif findmnt "${MOUNT_PATH}" &>/dev/null; then
            echo -e "\n${RED}Error:${NC} ${MOUNT_PATH} is already in use. Choose a different mount point.\n"
            return 1
        elif [[ -d "${MOUNT_PATH}" ]] && [[ -n "$(ls -A "${MOUNT_PATH}" 2>/dev/null)" ]]; then
            echo -e "\n${YELLOW}Warning:${NC} ${MOUNT_PATH} exists and is not empty. Files may be obscured after mounting.\n"
            read -p "Continue anyway? [y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi

        # Declare an array to store the paths of LUKS-encrypted files
        declare -a LUKS_FILES=()

        # Find all regular files in the directory and test if they are LUKS containers
        while IFS= read -r -d '' file; do
            if sudo cryptsetup isLuks "$file" 2>/dev/null; then
                LUKS_FILES+=("$file")
            fi
        done < <(find "${CONT_PATH}" -maxdepth 1 -type f -size +100M -print0 2>/dev/null)

        # Output the results
        if [[ ${#LUKS_FILES[@]} -eq "0" ]]; then
            echo -e "${BLUE}No LUKS-encrypted containers found in${NC} ${CONT_PATH}\n"
            return 1
        fi

        # Select container
        echo -e "\n${YELLOW}Select the LUKS container you want to mount:${NC}"
        PS3="Option: "
        select CONT_TARGET in "${LUKS_FILES[@]}" "Exit"; do
            if [[ "$CONT_TARGET" == "Exit" ]]; then
                echo -e "${BLUE}No LUKS container selected. Script will exit here.${NC}\n"
                return 1
            elif [[ -n "$CONT_TARGET" ]]; then
                echo -e "\n${CYAN}$CONT_TARGET${NC} container selected\n"
                break
            else
                echo "Invalid selection. Please choose a number from the list."
            fi
        done
    fi

    # Keyfile support
    echo -e "${BLUE}Searching for associated keyfiles in container dir...${NC}"

    local keyfile1 keyfile2 key_location

    keyfile1="${CONT_TARGET%.*}.key"
    keyfile2="${CONT_TARGET%.*}.keyfile"
    key_location=""

    if [[ -f "$keyfile1" ]]; then
        echo -e "${CYAN}${keyfile1}${NC} found."
        echo -e "Proceeding with keyfile support...\n"
        KEYFILE="$keyfile1"        
        KEYFILE_FLAG=1
    elif [[ -f "$keyfile2" ]]; then
        echo -e "${CYAN}${keyfile2}${NC} found."
        echo -e "Proceeding with keyfile support...\n"
        KEYFILE="$keyfile2"        
        KEYFILE_FLAG=1
    else
        echo -e "${YELLOW}Associated keyfile not found.${NC}"
        read -rp "Specify full path to keyfile (eg. /home/user/luks.keyfile) or leave empty to skip: " key_location
        if [[ -f ${key_location} ]]; then
            echo -e "${CYAN}${key_location}${NC} found. Proceeding with keyfile...\n"
            KEYFILE="$key_location"
            KEYFILE_FLAG=1
        else
            echo -e "${YELLOW}Keyfile not found.${NC}\nProceeding with password-only container support...\n"
        fi    
    fi   

    # Set container alias
    echo -e "${YELLOW}Create an alias to identify the working LUKS container.${NC}\nAvoid names with empty spaces. Use hyphens or underscores for multiple words"
    read -rp "(eg. company_records or cloud-archive): " CONT_ALIAS

    while [[ -z "${CONT_ALIAS}" ]]; do
        echo -e "${RED}Error:${NC} No alias set. Type a simple name."
        read -rp "Create alias: " CONT_ALIAS
    done

    # Validate alias (only alphanumeric, hyphens, underscores)
    if [[ ! "${CONT_ALIAS}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error:${NC} Alias contains invalid characters. Use only letters, numbers, hyphens, and underscores."
        return 1
    fi

    echo -e "\n${CYAN}'${CONT_ALIAS}'${NC} alias set for $CONT_TARGET\n"

    LOOP_NUM=$(sudo losetup -f --show "$CONT_TARGET")

    # Set up loop device
    if [[ -z "$LOOP_NUM" ]]; then
        echo -e "${RED}Error:${NC} Failed to set up loop device."
        return 1
    else
        echo "Loop device $LOOP_NUM attached"
    fi

    # Check for keyfile & open LUKS container
    if [[ -n "$KEYFILE_FLAG" ]]; then
        if ! sudo cryptsetup luksOpen "$LOOP_NUM" "${CONT_ALIAS}" --key-file "$KEYFILE"; then
            # Fallback if fails to open
            echo -e "${RED}Error:${NC} Failed to open LUKS container with keyfile. Falling back to opening container with password..."

            if ! sudo cryptsetup luksOpen "$LOOP_NUM" "${CONT_ALIAS}"; then
                echo -e "${RED}Error:${NC} Failed to open LUKS container."
                sudo losetup -d "$LOOP_NUM"
                return 1
            else
                echo "LUKS device open"
            fi
        fi
    else
        if ! sudo cryptsetup luksOpen "$LOOP_NUM" "${CONT_ALIAS}"; then
            echo -e "${RED}Error:${NC} Failed to open LUKS container."
            sudo losetup -d "$LOOP_NUM"
            return 1
        else
            echo "LUKS device open"
        fi
    fi

    # Check if mount point exists, create if it doesn't
    if [[ ! -d "${MOUNT_PATH}" ]]; then
        echo -e "${YELLOW}Warning:${NC} Mount point ${MOUNT_PATH} does not exist. Creating it..."
        if ! sudo mkdir -p "${MOUNT_PATH}"; then
            echo -e "${RED}Error:${NC} Failed to create mount point ${MOUNT_PATH}"
            sudo cryptsetup luksClose "${CONT_ALIAS}"
            sudo losetup -d "$LOOP_NUM"
            return 1
        fi
    fi

    # Mount filesystem
    if ! sudo mount /dev/mapper/"${CONT_ALIAS}" "${MOUNT_PATH}"; then
        echo -e "${RED}Error:${NC} Failed to mount /dev/mapper/${CONT_ALIAS} on ${MOUNT_PATH}"
        sudo cryptsetup luksClose "${CONT_ALIAS}"
        sudo losetup -d "$LOOP_NUM"
        return 1
    else
        echo -e "Filesystem mounted"
    fi

    # Export variables for global use (only export if all steps succeeded)
    export CONT_PATH MOUNT_PATH LOOP_NUM CONT_TARGET CONT_ALIAS

    # Success echo & set correct permissions
    sudo chown -R "$USER" "${MOUNT_PATH}"
    echo -e "${GREEN}Container mounted on: ${MOUNT_PATH}${NC}"
    echo -e "${GREEN}Write permissions set on: ${MOUNT_PATH}${NC}\n"
}


############################
# Close container function #
############################
cont_close() {
	# Position parameter
    CONT_ALIAS="$1"

    # Correct usage check
    if [[ -z "${CONT_ALIAS}" ]]; then
        echo -e "${YELLOW}Usage:${NC} cont-close ${CYAN}<container-alias>${NC}\n"
        return 1
    fi

    # More robust parsing using cryptsetup status
    local LOOP_NUM2=""
    local MOUNT_PATH=""
    local CONT_FILE=""

    # Get container file and loop device from cryptsetup status
    if sudo cryptsetup status "${CONT_ALIAS}" &>/dev/null; then
        # Parse loop device from cryptsetup status
        LOOP_NUM2=$(sudo cryptsetup status "${CONT_ALIAS}" | grep -i "device:" | awk '{print $2}')
        # Parse backing file
        CONT_FILE=$(sudo cryptsetup status "${CONT_ALIAS}" | grep -i "loop:" | awk '{print $2}')
    else
        echo -e "${RED}Error:${NC} Container alias '${CONT_ALIAS}' not found or not active."
        return 1
    fi

    # Try to find mount point from /proc/mounts or lsblk
    if [[ -n "$LOOP_NUM2" ]]; then
        # Try to get mount point from /dev/mapper device
        MOUNT_PATH=$(findmnt -n -o TARGET "/dev/mapper/${CONT_ALIAS}" 2>/dev/null)

        # Fallback to lsblk parsing if findmnt not available
        if [[ -z "${MOUNT_PATH}" ]]; then
            MOUNT_PATH=$(lsblk -o NAME,MOUNTPOINT | grep -i "${CONT_ALIAS}" | awk '{print $2}')
        fi
    fi

    # Validate container file
    if [[ -z "$CONT_FILE" ]]; then
        echo -e "${RED}Error:${NC} Cannot determine container file for alias '${CONT_ALIAS}'."
        return 1
    fi

    # Validate loop device
    if [[ -z "$LOOP_NUM2" ]]; then
        echo -e "${RED}Error:${NC} No active loop device found for alias '${CONT_ALIAS}'."
        unset CONT_FILE LOOP_NUM2 MOUNT_PATH CONT_ALIAS
        return 1
    fi

    # Unmount if mounted
    if [[ -n "${MOUNT_PATH}" && -d "${MOUNT_PATH}" ]]; then
        #echo "Unmounting ${MOUNT_PATH}..."
        sudo umount "${MOUNT_PATH}" 2>/dev/null && echo -e "${GREEN}Unmounted ${MOUNT_PATH}${NC}" || echo -e "${YELLOW}Warning: Could not unmount ${MOUNT_PATH} (might already be unmounted)${NC}"
    else
        echo -e "${YELLOW}Note: No mount point found for ${CONT_ALIAS}${NC}"
    fi

    # Close LUKS container
    sudo cryptsetup luksClose "${CONT_ALIAS}" 2>/dev/null && echo -e "${GREEN}LUKS device closed${NC}" || echo -e "${YELLOW}Warning: Could not close LUKS container (might already be closed)${NC}"

    # Detach loop device
    sudo losetup -d "$LOOP_NUM2" 2>/dev/null && echo -e "$