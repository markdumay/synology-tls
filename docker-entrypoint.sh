#!/bin/sh

# Halt script execution on any error
set -e 

# Export Docker secrets as environment variables without displaying any errors / messages
export $(grep -vH --null '^#' /run/secrets/* | tr '\0' '=' | sed 's/^\/run\/secrets\///g') > /dev/null 2>&1

# Set default values for flags and environment variables
export TEST_FLAG='--test'
export RENEW_FLAG=''
export NOTIFY_FLAG=''
export DEPLOY_CMD=''
if [ -z "${STAGE}" ]; then export STAGE='staging'; fi
if [ -z "${FORCE_RENEW}" ]; then export FORCE_RENEW='false'; fi
if [ -z "${NOTIFY_LEVEL}" ]; then export NOTIFY_LEVEL='2'; fi

# Convert selected environment variables to lower case
export STAGE=$( echo "$STAGE" | tr -s  '[:upper:]'  '[:lower:]' )
export FORCE_RENEW=$( echo "$FORCE_RENEW" | tr -s  '[:upper:]'  '[:lower:]' )

# Update flags based on environment variables
if [[ $STAGE = 'production' ]] ; then export TEST_FLAG=''; fi; 
if [[ $FORCE_RENEW = 'true' ]] ; then export RENEW_FLAG='--force'; fi; 
if [ ! -z "${NOTIFY_HOOK}" ] ; then 
    export NOTIFY_FLAG="--notify-level $NOTIFY_LEVEL --notify-hook $NOTIFY_HOOK"; 
fi; 
if [ ! -z "${DEPLOY_HOOK}" ] ; then 
    export DEPLOY_CMD="acme.sh --deploy -d '${DOMAIN}' --deploy-hook $DEPLOY_HOOK"; 
fi; 

# Call parent's entry script in current script context
. /entry.sh