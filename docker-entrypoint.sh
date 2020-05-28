#!/bin/sh

# Halt script execution on any error
set -e 

# Set default values for flags and variables
TEST_FLAG='--test'
RENEW_FLAG=''
NOTIFY_FLAG=''
DEPLOY_CMD=''
if [ -z "${STAGE}" ]; then STAGE='staging'; fi
if [ -z "${FORCE_RENEW}" ]; then FORCE_RENEW='false'; fi
if [ -z "${NOTIFY_LEVEL}" ]; then NOTIFY_LEVEL='2'; fi

# Convert selected environment variables to lower case
STAGE=$( echo "$STAGE" | tr -s  '[:upper:]'  '[:lower:]' )
FORCE_RENEW=$( echo "$FORCE_RENEW" | tr -s  '[:upper:]'  '[:lower:]' )

# Update flags based on environment variables
if [[ $STAGE = 'production' ]] ; then TEST_FLAG=''; fi; 
if [[ $FORCE_RENEW = 'true' ]] ; then RENEW_FLAG='--force'; fi; 
if [ ! -z "${NOTIFY_HOOK}" ] ; then 
    NOTIFY_FLAG="--set-notify --notify-level $NOTIFY_LEVEL --notify-hook $NOTIFY_HOOK"; 
fi; 
if [ ! -z "${DEPLOY_HOOK}" ] ; then 
    DEPLOY_CMD="acme.sh -d '${DOMAIN}' --deploy --deploy-hook $DEPLOY_HOOK"; 
    else
    DEPLOY_CMD="echo 'Please specify a deploy_hook in your environment'"; 
fi; 

# Generate a script to issue / renew certificates
printf "%b" '#!'"/usr/bin/env sh\n \
. /usr/local/bin/stage-env.sh
acme.sh --issue -d '${DOMAIN}' -d '*.${DOMAIN}' --dns dns_cf $TEST_FLAG $RENEW_FLAG
" >/usr/local/bin/issue.sh && chmod +x /usr/local/bin/issue.sh

# Generate a script to deploy certificates
printf "%b" '#!'"/usr/bin/env sh\n \
. /usr/local/bin/stage-env.sh
$DEPLOY_CMD
" >/usr/local/bin/deploy.sh && chmod +x /usr/local/bin/deploy.sh

# Replace default cronjob when the schedule is specified
if [ ! -z "${CRON_SCHEDULE}" ] ; then 
    # Generate a cron job script (running acme.sh upgrade, issue.sh, and deploy.sh)
    printf "%b" '#!'"/usr/bin/env sh\n \
    acme.sh --upgrade && issue.sh && deploy.sh
    " >/usr/local/bin/cron.sh && chmod +x /usr/local/bin/cron.sh

    # Remove default cronjob
    acme.sh --uninstall-cronjob

    # Install custom cronjob if not added already
    echo "[$(date -u)] Adding custom cron job at '$CRON_SCHEDULE'"
    echo "[$(date -u)] View the cron log in '/var/log/acme.log'"
    ! (crontab -l | grep -q "cron.sh") && (crontab -l; echo "$CRON_SCHEDULE cron.sh >> /var/log/acme.log 2>&1") | crontab -

    # Run cronjob during start-up to immediately see the outcomes in the service log
    cron.sh
fi;

# Call parent's entry script in current script context
. /entry.sh