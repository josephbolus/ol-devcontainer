# Use a specific Ubuntu version for better reproducibility
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Find the latest URL from: https://dev.mysql.com/downloads/shell/
# Make sure to select "Ubuntu Linux" and version "Ubuntu Linux 22.04 (x86, 64-bit)"
ARG MYSQL_SHELL_URL="https://dev.mysql.com/get/Downloads/MySQL-Shell/mysql-shell_8.0.43-1ubuntu22.04_amd64.deb"

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install MySQL client, Git, Nano, and Midnight Commander
RUN apt-get update && \
    # 1. Install prerequisite tools and your desired utilities
    #    - gnupg is needed for key management for the new repository.
    #    - jq is a required dependency for the mysql-clone-replicate.sh script.
    apt-get install -y --no-install-recommends \
    gnupg \
    wget \
    curl \
    jq \
    openssh-client \
    mysql-client \
    percona-toolkit \
    git \
    nano \
    mc \
    htop && \
    # --- Install Official MySQL Shell --- \
    DEB_FILE=$(basename "${MYSQL_SHELL_URL}") && \
    wget -O "${DEB_FILE}" "${MYSQL_SHELL_URL}" && \
    apt-get install -y "./${DEB_FILE}" && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* mysql-apt-config.deb
