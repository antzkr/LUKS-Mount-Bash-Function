######################################################
# Bash function to mount an encrypted LUKS container #
# (launch with bash_aliases)                         #
# Multiple mounted containers supported              #
#                                                    #
# Syntax for opening and closing LUKS containters:   #
#   cont-open <container-dir> <mount-dir>            #
#   cont-close <container-alias>                     #
######################################################

# v6 - improved finding luks container logic & readability


###########################
# Open container function #
###########################
cont() {
	# Position parameters
    CONT_PATH="$1"
    MOUNT_PATH="$2"

    # Correct usage check
    if [[ -z "$CONT_PATH" || -z "$MOUNT_PATH" ]]; then
        echo -e "${YELLOW}Usage:${RESET} cont-open ${CYAN}<container-dir> <mount-point>${RESET}\n"
        return 1
    else
        # Validate the container & mount paths
        if [[ ! -d "$CONT_PATH" ]]; then
            echo -e "\n${RED}Error:${RESET} $CONT_PATH is not a valid directory.\n" >&2
            return 1
        elif findmnt "$MOUNT_PATH" &>/dev/null; then
            echo -e "\n${RED}Error:${RESET} $MOUNT_PATH is already in use. Choose a different mount point.\n"
            return 1
        elif [[ -d "$MOUNT_PATH" ]] && [[ -n "$(ls -A "$MOUNT_PATH" 2>/dev/null)" ]]; then
            echo -e "\n${YELLOW}Warning:${RESET} $MOUNT_PATH exists and is not empty. Files may be obscured after mounting.\n"
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
	    # Uncomment for debugging
	    #echo -e "${CYAN}Found LUKS container:${RESET} $file\n"
            fi
        done < <(find "$CONT_PATH" -maxdepth 1 -type f -size +100M -print0 2>/dev/null)

        # Output the results
        if [[ ${#LUKS_FILES[@]} -eq 0 ]]; then
            echo -e "${BLUE}No LUKS-encrypted containers found in${RESET} $CONT_PATH\n"
            return 1
        #else
            # Uncomment for debugging
            #echo ""
            #echo -e "${YELLOW}Found ${#LUKS_FILES[@]} LUKS-encrypted file(s):${RESET}"
            #for file in "${LUKS_FILES[@]}"; do
               # echo "$file"
            #done
        fi

        # Select container
        echo -e "\n${YELLOW}Select the LUKS container you want to mount:${RESET}"
        PS3="Option: "
        select CONT_TARGET in "${LUKS_FILES[@]}" "Exit"; do
            if [[ "$CONT_TARGET" == "Exit" ]]; then
                echo -e "${BLUE}No LUKS container selected. Script will exit here.${RESET}\n"
                return 1
            elif [[ -n "$CONT_TARGET" ]]; then
                echo -e "\n${CYAN}$CONT_TARGET${RESET} container selected\n"
                break
            else
                echo "Invalid selection. Please choose a number from the list."
            fi
        done
    fi

    # Set container alias
    echo -e "${YELLOW}Create an alias to identify the working LUKS container.${RESET}\nAvoid names with empty spaces. Use hyphens or underscores for multiple words"
    read -p "(eg. company_records or cloud-archive): " CONT_ALIAS

    while [[ -z $CONT_ALIAS ]]; do
        echo -e "${RED}Error:${RESET} No alias set. Type a simple name."
        read -p "Create alias: " CONT_ALIAS
    done

    # Validate alias (only alphanumeric, hyphens, underscores)
    if [[ ! "$CONT_ALIAS" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error:${RESET} Alias contains invalid characters. Use only letters, numbers, hyphens, and underscores."
        return 1
    fi

    echo -e "\n${CYAN}'$CONT_ALIAS'${RESET} alias set for $CONT_TARGET\n"

    LOOP_NUM=$(sudo losetup -f --show "$CONT_TARGET")

    # Set up loop device
    if [[ -z "$LOOP_NUM" ]]; then
        echo -e "${RED}Error:${RESET} Failed to set up loop device."
        return 1
    else
        echo "Loop device $LOOP_NUM attached"
    fi

    # Open LUKS container
    if ! sudo cryptsetup luksOpen "$LOOP_NUM" "$CONT_ALIAS"; then
        echo -e "${RED}Error:${RESET} Failed to open LUKS container."
        sudo losetup -d "$LOOP_NUM"
        return 1
    else
        echo "LUKS device open"
    fi

    # Check if mount point exists, create if it doesn't
    if [[ ! -d "$MOUNT_PATH" ]]; then
        echo -e "${YELLOW}Warning:${RESET} Mount point $MOUNT_PATH does not exist. Creating it..."
        sudo mkdir -p "$MOUNT_PATH"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Error:${RESET} Failed to create mount point $MOUNT_PATH"
            sudo cryptsetup luksClose "$CONT_ALIAS"
            sudo losetup -d "$LOOP_NUM"
            return 1
        fi
    fi

    # Mount filesystem
    if ! sudo mount /dev/mapper/"$CONT_ALIAS" "$MOUNT_PATH"; then
        echo -e "${RED}Error:${RESET} Failed to mount /dev/mapper/$CONT_ALIAS on $MOUNT_PATH"
        sudo cryptsetup luksClose "$CONT_ALIAS"
        sudo losetup -d "$LOOP_NUM"
        return 1
    else
        echo -e "Filesystem mounted"
    fi

    # Export variables for global use (only export if all steps succeeded)
    export CONT_PATH MOUNT_PATH LOOP_NUM CONT_TARGET CONT_ALIAS

    # Success echo & set correct permissions
    sudo chown -R "$USER" "$MOUNT_PATH"
    echo -e "${GREEN}Container mounted on: $MOUNT_PATH${RESET}"
    echo -e "${GREEN}Write permissions set on: $MOUNT_PATH${RESET}\n"
}


############################
# Close container function #
############################
cont_close() {
	# Position parameter
    CONT_ALIAS2="$1"

    # Correct usage check
    if [[ -z "$CONT_ALIAS2" ]]; then
        echo -e "${YELLOW}Usage:${RESET} cont-close ${CYAN}<container-alias>${RESET}\n"
        return 1
    fi

    # More robust parsing using cryptsetup status
    local LOOP_NUM2=""
    local MOUNT_PATH2=""
    local CONT_FILE=""

    # Get container file and loop device from cryptsetup status
    if sudo cryptsetup status "$CONT_ALIAS2" &>/dev/null; then
        # Parse loop device from cryptsetup status
        LOOP_NUM2=$(sudo cryptsetup status "$CONT_ALIAS2" | grep -i "device:" | awk '{print $2}')
        # Parse backing file
        CONT_FILE=$(sudo cryptsetup status "$CONT_ALIAS2" | grep -i "loop:" | awk '{print $2}')
    else
        echo -e "${RED}Error:${RESET} Container alias '$CONT_ALIAS2' not found or not active."
        return 1
    fi

    # Try to find mount point from /proc/mounts or lsblk
    if [[ -n "$LOOP_NUM2" ]]; then
        # Try to get mount point from /dev/mapper device
        MOUNT_PATH2=$(findmnt -n -o TARGET "/dev/mapper/$CONT_ALIAS2" 2>/dev/null)

        # Fallback to lsblk parsing if findmnt not available
        if [[ -z "$MOUNT_PATH2" ]]; then
            MOUNT_PATH2=$(lsblk -o NAME,MOUNTPOINT | grep -i "$CONT_ALIAS2" | awk '{print $2}')
        fi
    fi

    # Validate container file
    if [[ -z "$CONT_FILE" ]]; then
        echo -e "${RED}Error:${RESET} Cannot determine container file for alias '$CONT_ALIAS2'."
        return 1
    fi

    # Validate loop device
    if [[ -z "$LOOP_NUM2" ]]; then
        echo -e "${RED}Error:${RESET} No active loop device found for alias '$CONT_ALIAS2'."
        unset CONT_FILE LOOP_NUM2 MOUNT_PATH2 CONT_ALIAS2
        return 1
    fi

    # Unmount if mounted
    if [[ -n "$MOUNT_PATH2" && -d "$MOUNT_PATH2" ]]; then
        #echo "Unmounting $MOUNT_PATH2..."
        sudo umount "$MOUNT_PATH2" 2>/dev/null && echo -e "${GREEN}Unmounted $MOUNT_PATH2${RESET}" || echo -e "${YELLOW}Warning: Could not unmount $MOUNT_PATH2 (might already be unmounted)${RESET}"
    else
        echo -e "${YELLOW}Note: No mount point found for $CONT_ALIAS2${RESET}"
    fi

    # Close LUKS container
    #echo "Closing LUKS container $CONT_ALIAS2..."
    sudo cryptsetup luksClose "$CONT_ALIAS2" 2>/dev/null && echo -e "${GREEN}LUKS device closed${RESET}" || echo -e "${YELLOW}Warning: Could not close LUKS container (might already be closed)${RESET}"

    # Detach loop device
    #echo "Detaching loop device $LOOP_NUM2..."
    sudo losetup -d "$LOOP_NUM2" 2>/dev/null && echo -e "${GREEN}Loop device $LOOP_NUM2 detached${RESET}" || echo -e "${YELLOW}Warning: Could not detach loop device (might already be detached)${RESET}"

    # Unset environment variables if they were set by cont()
    unset CONT_FILE LOOP_NUM2 MOUNT_PATH2 CONT_ALIAS2

    # Optionally unset the exported variables from cont()
    unset CONT_PATH MOUNT_PATH LOOP_NUM CONT_TARGET CONT_ALIAS

    echo -e "${BLUE}Container safely unmounted and closed${RESET}\n"
}
