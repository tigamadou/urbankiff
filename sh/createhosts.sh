#!/bin/bash
# Source the external color variables file
source ./sh/colors.sh


# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "${RED}Please run as root or use sudo${RED}"
    exit
fi
## Edit the hostfile
# Entries to add
LOCAL_IP="127.0.0.1"
REACT_DEV_HOSTNAME="urbankiff.local"
REACT_ADMIN_HOSTNAME="api.urbankiff.local"
BACKEND_HOSTNAME="panel.urbankiff.local"
PGADMIN_HOSTNAME="urbankiffdbpgadmin.local"
S30_HOSTNAME="s30.urbankiff.local"
S3_HOSTNAME="s3.urbankiff.local"

echo "${RESET}Creating hosts entries......${RESET}"

# Check if the entries already exist in the hosts file

# REACT_DEV_HOSTNAME
if grep -Fxq "$LOCAL_IP $REACT_DEV_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $REACT_DEV_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $REACT_DEV_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $REACT_DEV_HOSTNAME to hosts file.${GREEN}"
fi

# REACT_ADMIN_HOSTNAME
if grep -Fxq "$LOCAL_IP $REACT_ADMIN_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $REACT_ADMIN_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $REACT_ADMIN_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $REACT_ADMIN_HOSTNAME to hosts file.${GREEN}"
fi

# BACKEND_HOSTNAME
if grep -Fxq "$LOCAL_IP $BACKEND_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $BACKEND_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $BACKEND_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $BACKEND_HOSTNAME to hosts file.${GREEN}"
fi

# PGADMIN_HOSTNAME
if grep -Fxq "$LOCAL_IP $PGADMIN_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $PGADMIN_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $PGADMIN_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $PGADMIN_HOSTNAME to hosts file.${GREEN}"
fi

# S3_HOSTNAME
if grep -Fxq "$LOCAL_IP $S3_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $S3_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $S3_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $S3_HOSTNAME to hosts file.${GREEN}"
fi

#CDN_HOSTNAME
if grep -Fxq "$LOCAL_IP $S30_HOSTNAME" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP $S30_HOSTNAME already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP $S30_HOSTNAME" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP $S30_HOSTNAME to hosts file.${GREEN}"
fi

#NEXTJS_HOSTNAME
if grep -Fxq "$LOCAL_IP ${FRONT_NEXTJS_HOSTNAME}" /etc/hosts; then
    echo "  ${YELLOW}Entry $LOCAL_IP ${FRONT_NEXTJS_HOSTNAME} already exists in hosts file.${YELLOW}"
else
    echo "$LOCAL_IP ${FRONT_NEXTJS_HOSTNAME}" >> /etc/hosts
    echo "  ${GREEN}Added $LOCAL_IP ${FRONT_NEXTJS_HOSTNAME} to hosts file.${GREEN}"
fi