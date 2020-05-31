#!/bin/sh
# source https://community.synology.com/enu/forum/1/post/131600
# https://gist.github.com/Mikado8231/bf207a019373f9e539af4d511ae15e0d

# TODO: add restore

##### Script variables and constants #####
WORKING_DIR=/tmp/docker_update
DOCKER_BACKUP_FILENAME=docker_backup_$(date +%Y%m%d_%H%M%S).tar.gz
SYNO_DOCKER_SERV_NAME=pkgctl-Docker
SYNO_DOCKER_DIR=/var/packages/Docker
SYNO_DOCKER_BIN=$SYNO_DOCKER_DIR/target/usr/bin
SYNO_DOCKER_JSON=$SYNO_DOCKER_DIR/etc/dockerd.json
DOWNLOAD_DOCKER=https://download.docker.com/linux/static/stable/x86_64
DOWNLOAD_GITHUB=https://github.com/docker/compose
DSM_SUPPORTED_VERSION=6
SKIP_DOCKER_UPDATE='false'
SKIP_COMPOSE_UPDATE='false'
STEP=1
TOTAL_STEPS=8
FORCE='false'
UPDATE='false'
CLEAN='false'
TARGET_DOCKER_VERSION=''
TARGET_COMPOSE_VERSION=''


##### Functions #####

# Display usage message
usage() { 
    echo "Usage: $0 [OPTIONS] update" 
    echo
    echo "Options:"
    echo "  -c, --compose VERSION  Docker Compose target version (defaults to latest)"
    echo "  -d, --docker VERSION   Docker target version (defaults to latest)"
    echo "  -f, --force            Force update (bypass compatibility check)"
###    echo "  -c, --clean            Remove previous backups"
    echo
}

# Display error message and terminate with non-zero error
terminate() {
    echo "ERROR: $1"
    echo
    exit 1
}

# Prints current progress to the console
print_status () {
    echo "Step $((STEP++)) from $TOTAL_STEPS: $1"
}

# Detects current versions for DSM, Docker, and Docker Compose
detect_current_versions() {
    # Detect current DSM version
    DSM_VERSION=$(cat /etc.defaults/VERSION 2> /dev/null | grep '^productversion' | cut -d'=' -f2 | sed "s/\"//g")
    DSM_MAJOR_VERSION=$(cat /etc.defaults/VERSION 2> /dev/null | grep '^majorversion' | cut -d'=' -f2)
    DSM_BUILD=$(cat /etc.defaults/VERSION 2> /dev/null | grep '^buildnumber' | cut -d'=' -f2)

    # Detect current Docker version
    DOCKER_VERSION=$(docker -v | egrep -o "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)

    # Detect current Docker Compose version
    COMPOSE_VERSION=$(docker-compose -v | egrep -o "[0-9]*.[0-9]*.[0-9]*," | cut -d',' -f 1)
}

# Validates current versions for DSM, Docker, and Docker Compose
validate_current_version() {
    # Test if host is DSM 6, exit otherwise
    if [ "$DSM_MAJOR_VERSION" != "$DSM_SUPPORTED_VERSION" ] ; then
        terminate "This script supports DSM 6.x only, use --force to override"
    fi

    # Test Docker version is present, exit otherwise
    if [ -z "$DOCKER_VERSION" ] ; then
        terminate "Could not detect current Docker version, use --force to override"
    fi

    # Test Docker Compose version is present, exit otherwise
    if [ -z "$COMPOSE_VERSION" ] ; then
        terminate "Could not detect current Docker Compose version, use --force to override"
    fi
}

# Detects available versions for Docker and Docker Compose
detect_available_versions() {
    # Detect latest available Docker version
    if [ -z "$TARGET_DOCKER_VERSION" ] ; then
        DOCKER_BIN_FILES=$(curl -s "$DOWNLOAD_DOCKER/" | egrep -o '>docker-[0-9]*.[0-9]*.[0-9]*(-ce)?.tgz' | cut -c 2-)
        LATEST_DOCKER_BIN=$(echo "$DOCKER_BIN_FILES" | sort -bt. -k1,1 -k2,2n -k3,3n -k4,4n -k5,5n | tail -1)
        LATEST_DOCKER_VERSION=$(echo "$LATEST_DOCKER_BIN" | sed "s/docker-//g" | sed "s/.tgz//g" )
        TARGET_DOCKER_VERSION=$LATEST_DOCKER_VERSION
    fi

    # Detect latest available stable Docker Compose version (ignores release candidates)
    if [ -z "$TARGET_COMPOSE_VERSION" ] ; then
        COMPOSE_TAGS=$(curl -s "$DOWNLOAD_GITHUB/tags" | egrep "a href=\"/docker/compose/releases/tag/[0-9]+.[0-9]+.[0-9]+\"")
        LATEST_COMPOSE_VERSION=$(echo "$COMPOSE_TAGS" | head -1 | cut -c 45- | sed "s/\">//g")
        TARGET_COMPOSE_VERSION=$LATEST_COMPOSE_VERSION
    fi
}

# Validates available updates for Docker and Docker Compose
validate_available_versions() {
    # Test Docker is available for download, exit otherwise
    if [ -z "$TARGET_DOCKER_VERSION" ] ; then
        terminate "Could not find Docker binaries for downloading"
    fi

    # Test Docker Compose is available for download, exit otherwise
    if [ -z "$TARGET_COMPOSE_VERSION" ] ; then
        terminate "Could not find Docker Compose binaries for downloading"
    fi
}

# Validates user input conforms to expected version pattern
validate_version_input() {
    VALIDATION=$(echo "$1" | egrep -o "^[0-9]+.[0-9]+.[0-9]+")
    if [ "$VALIDATION" != "$1" ] ; then
        usage
        terminate "$2"
    fi
}

# Defines update strategy for Docker and Docker Compose
define_update() {
    # Confirm update is necessary
    if [ "$DOCKER_VERSION" = "$TARGET_DOCKER_VERSION" ] && [ "$COMPOSE_VERSION" = "$TARGET_COMPOSE_VERSION" ] ; then
        terminate "Already on target version for Docker and Docker Compose"
    fi
    if [ "$DOCKER_VERSION" = "$TARGET_DOCKER_VERSION" ] ; then
        SKIP_DOCKER_UPDATE='true'
        TOTAL_STEPS=$((TOTAL_STEPS-1))
    fi
    if [ "$COMPOSE_VERSION" = "$TARGET_COMPOSE_VERSION" ] ; then
        SKIP_COMPOSE_UPDATE='true'
        TOTAL_STEPS=$((TOTAL_STEPS-1))
    fi
}

##### Main #####

# Show header
echo "Update Docker Engine and Docker Compose on Synology to target version"
echo 

##### Main - Validations #####

# Test if script has root privileges, exit otherwise
if [[ $(id -u) -ne 0 ]]; then 
    usage
    terminate "You need to be root to run this script"
fi

# Process and validate command-line arguments
while [ "$1" != "" ]; do
    case "$1" in
        -c | --compose )
            shift
            TARGET_COMPOSE_VERSION="$1"
            validate_version_input "$TARGET_COMPOSE_VERSION" "Unrecognized target Docker Compose version"
            ;;
        -d | --docker )
            shift
            TARGET_DOCKER_VERSION="$1"
            validate_version_input "$TARGET_DOCKER_VERSION" "Unrecognized target Docker version"
            ;;
        -f | --force )
            FORCE='true'
            ;;
        -h | --help )
            usage
            exit
            ;;
        update )
            UPDATE='true'
            ;;
        -* )
            usage
            exit 1
            ;;
        * )
            NAME="$1"
    esac
    shift
done

# Validate update command is present
if [ "$UPDATE" != 'true' ] ; then 
    usage
    exit 1
fi; 

# Detect current software versions
detect_current_versions
echo "Current DSM version: $(printf ${DSM_VERSION:-Unknown})"
echo "Current Docker version: $(printf ${DOCKER_VERSION:-Unknown})"
echo "Current Docker Compose version: $(printf ${COMPOSE_VERSION:-Unknown})"
if [ "$FORCE" != 'true' ] ; then
    validate_current_version
fi

# Detect available software versions
detect_available_versions
echo "Target Docker version: $(printf ${TARGET_DOCKER_VERSION:-Unknown})"
echo "Target Docker Compose version: $(printf ${TARGET_COMPOSE_VERSION:-Unknown})"
validate_available_versions
if [ "$FORCE" != 'true' ] ; then
    define_update
fi
echo


##### Main - Script execution #####

# Stop Docker service if running
print_status "Stopping Docker service"
###synoservicectl --status $SYNO_DOCKER_SERV_NAME | grep running -q && synoservicectl --stop $SYNO_DOCKER_SERV_NAME

# Prepare working environment
print_status "Preparing working environment ($WORKING_DIR/)"
mkdir -p "$WORKING_DIR"
# if [ "$CLEAN" == 'true' ] ; then
#    rm -f "$WORKING_DIR/docker/*""
# fi

# Backup previous Docker binaries
print_status "Backing up previous Docker binaries ($DOCKER_BACKUP_FILENAME)"
# tar -czf "$WORKING_DIR/$DOCKER_BACKUP_FILENAME $SYNO_DOCKER_BIN $SYNO_DOCKER_JSON"
# if [ ! -f "$WORKING_DIR/$DOCKER_BACKUP_FILENAME" ] ; then
#     terminate "Backup issue"
# fi

# Download and install target Docker binary
if [ "$SKIP_DOCKER_UPDATE" == 'false' ] ; then
    print_status "Downloading target Docker binary ($DOWNLOAD_DOCKER/docker-$TARGET_DOCKER_VERSION.tgz)"
    #wget "$DOWNLOAD_DOCKER/docker-$TARGET_DOCKER_VERSION.tgz" -qO - | tar -zxvf - -C "$WORKING_DIR"
    # if [ ! -d "$WORKING_DIR/docker" ] ; then 
    #     terminate "Binary could not be dowloaded/unarchived"
    # fi
    #mv "$WORKING_DIR/docker/* $SYNO_DOCKER_BIN/"
fi

# Download and install target stable Docker Compose binary
if [ "$SKIP_COMPOSE_UPDATE" == 'false' ] ; then
    print_status "Downloading target Docker Compose binary ($DOWNLOAD_GITHUB/releases/download/$TARGET_COMPOSE_VERSION/docker-compose-Linux-x86_64)"
    #wget "$DOWNLOAD_GITHUB/releases/download/$TARGET_COMPOSE_VERSION/docker-compose-Linux-x86_64 -o $SYNO_DOCKER_BIN/docker-compose"
    #wget "$DOWNLOAD_GITHUB/releases/download/$TARGET_COMPOSE_VERSION/docker-compose-Linux-x86_64 -o $WORKING_DIR/docker-compose"
fi

# Set execution rights to binaries
print_status "Setting execution rights to binaries"
#chmod +x "$SYNO_DOCKER_BIN/*"

# Check log driver
print_status "Checking log driver"
if [ ! -f "$SYNO_DOCKER_JSON" ] || grep "json-file" "$SYNO_DOCKER_JSON" -q ; then
    mkdir -p "$SYNO_DOCKER_DIR/etc/"
    cat <<EOF > "$SYNO_DOCKER_JSON"
{
  "data-root" : "$SYNO_DOCKER_DIR/target/docker",
  "log-driver" : "json-file",
  "registry-mirrors" : [],
  "group": "administrators"
}
EOF
fi

# Start Docker service
print_status "Starting Docker service"
# synoservicectl --start "$SYNO_DOCKER_SERV_NAME"
# synoservicectl --status "$SYNO_DOCKER_SERV_NAME" | grep running -v && terminate "Could not bring Docker Engine back online"

echo "Done."