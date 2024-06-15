#!/usr/bin/env bash
###
# File: install-latest-sunshine.sh
# Project: scripts
# File Created: Monday, 15th June 2024 6:26:47 pm
# Author: luzfcb (bnafta@gmail.com)
# -----
# Last Modified: Monday, 15th June 2024 6:26:47 pm
# Modified By: luzfcb (bnafta@gmail.com)
###
#
# About:
#   This script fetches and installs the latest release of the Sunshine package from GitHub during container startup.
#   The script will only install a new version if the currently installed version is older than the most current version on GitHub.
#   Please note that we do not guarantee that the most current version will be compatible with your existing configuration.
#
# Guide:
#   Add this script to your startup scripts by running:
#       $ ln -sf "./scripts/install-latest-sunshine.sh" "${USER_HOME:?}/init.d/install-latest-sunshine.sh"
#
###


set -euo pipefail


# Configuration variables
GITHUB_REPO="LizardByte/Sunshine"
ASSET_NAME="sunshine-debian-bookworm-amd64.deb"
PACKAGE_NAME="sunshine"


RETRY_COUNT=5
RETRY_DELAY=10

# Import helpers
source "${USER_HOME:?}/init.d/helpers/functions.sh"

# Ensure this script is being executed as the default user
exec_script_as_default_user


# Function to extract the version number from the '${PACKAGE_NAME} --version' output
extract_version() {
  echo "$1" | grep -oP 'Sunshine version: v\K[0-9]+\.[0-9]+\.[0-9]+'
}

# Fetch the latest release information from the GitHub repository
response=$(curl -s --retry ${RETRY_COUNT} --retry-delay ${RETRY_DELAY} --retry-connrefused "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")

# Check if the response is empty
if [ -z "${response}" ]; then
  echo ">>>>> Failed to fetch release information."
  exit 1
fi

# Extract the tag_name and the .deb file URL
remote_version=$(echo "${response}" | jq -r '.tag_name')
url=$(echo "${response}" | jq -r ".assets[] | select(.name == \"${ASSET_NAME}\").browser_download_url")

# Check if the variables are empty
if [ -z "${remote_version}" ] || [ -z "${url}" ]; then
  echo ">>>>> Failed to extract tag name or URL."
  exit 1
fi

# Extract the numerical part of the remote version
remote_version_num=${remote_version#v}

# Flag to determine if installation is needed
install_needed=false

# Check if the package is installed
if ! command -v ${PACKAGE_NAME} &>/dev/null; then
  echo ">>>>> ${PACKAGE_NAME} is not installed. Proceeding with the installation of the latest version..."
  install_needed=true
else
  # Get the current installed version of the package
  current_version_output=$(${PACKAGE_NAME} --version)

  # Extract the current version number
  current_version=$(extract_version "${current_version_output}")

  # Check if the current version was extracted successfully
  if [ -z "${current_version}" ]; then
    echo ">>>>> Failed to extract the current installed version of ${PACKAGE_NAME}."
    exit 1
  fi

  # Compare the current version with the remote version
  if dpkg --compare-versions "${current_version}" lt "${remote_version_num}"; then
    echo ">>>>> A newer version of ${PACKAGE_NAME} is available: ${remote_version}. Proceeding with the update..."
    install_needed=true
  else
    echo ">>>>> ${PACKAGE_NAME} is already up-to-date (version ${current_version})."
  fi
fi

# Install or update if needed
if [ "${install_needed}" = true ]; then
  # Download the latest version
  if ! curl -L --retry ${RETRY_COUNT} --retry-delay ${RETRY_DELAY} --retry-connrefused -o "${PACKAGE_NAME}-latest.deb" "${url}"; then
    echo ">>>>> Failed to download the latest version of ${PACKAGE_NAME}."
    exit 1
  fi

  # Install the latest version
  sudo dpkg -i "${PACKAGE_NAME}-latest.deb"

  # Clean up
  rm "${PACKAGE_NAME}-latest.deb"

  echo ">>>>> ${PACKAGE_NAME} has been installed/updated to version ${remote_version}."
fi

echo "DONE"
