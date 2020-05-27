#!/bin/sh

# Read secret string
read_secret() {
    # Disable echo.
    stty -echo

    # Set up trap to ensure echo is enabled before exiting if the script
    # is terminated while echo is disabled.
    trap 'stty echo' EXIT

    # Read secret.
    read "$@"

    # Enable echo.
    stty echo
    trap - EXIT

    # Print a newline because the newline entered by the user after
    # entering the passcode is not echoed. This ensures that the
    # next line of output begins at a new line.
    echo
}

# Display usage message
usage() { 
    echo "Usage: $0 [OPTIONS] SECRET" 1>&2; 
    echo "" 1>&2;
    echo "Create a Docker secret from a prompt as content" 1>&2;
    echo "" 1>&2;
    echo "Options:" 1>&2;
    echo "  -d, --driver string            Secret driver" 1>&2;
    echo "  -l, --label list               Secret labels" 1>&2;
    echo "      --template-driver string   Template driver" 1>&2;
    echo "" 1>&2;
}

# Store and validate command-line arguments
ARGS="$@"
while [ "$1" != "" ]; do
    case $1 in
        -d | --driver | -l | --label | --template-driver )
            shift
            ;;
        -h | --help )
            usage
            exit
            ;;
        -* )
            usage
            exit 1
            ;;
        * )
            NAME=$1
    esac
    shift
done

# Validate secret name is provided
if [ -z "$NAME" ] ; then
    usage
    exit 1
fi

# Read the secret
printf "Secret: "
read_secret secret

# Pass secret to Docker
( cat <<EOF
$secret
EOF
) | docker secret create $ARGS -