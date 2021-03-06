FROM alpine:3.11

# Add GNU grep and logrotate on top of neilpang/acme.sh:latest
RUN apk update -f \
  && apk --no-cache add -f \
  openssl \
  openssh-client \
  coreutils \
  bind-tools \
  curl \
  socat \
  tzdata \
  oath-toolkit-oathtool \
  tar \
  grep \
  logrotate \
  && rm -rf /var/cache/apk/*

ENV LE_CONFIG_HOME /acme.sh

ENV AUTO_UPGRADE 1

#Install
ADD ./ /install_acme.sh/
RUN cd /install_acme.sh && ([ -f /install_acme.sh/acme.sh ] && /install_acme.sh/acme.sh --install || curl https://get.acme.sh | sh) && rm -rf /install_acme.sh/


RUN ln -s  /root/.acme.sh/acme.sh  /usr/local/bin/acme.sh && crontab -l | grep acme.sh | sed 's#> /dev/null##' | crontab -

RUN for verb in help \
  version \
  install \
  uninstall \
  upgrade \
  issue \
  signcsr \
  deploy \
  install-cert \
  renew \
  renew-all \
  revoke \
  remove \
  list \
  showcsr \
  install-cronjob \
  uninstall-cronjob \
  cron \
  toPkcs \
  toPkcs8 \
  update-account \
  register-account \
  create-account-key \
  create-domain-key \
  createCSR \
  deactivate \
  deactivate-account \
  set-notify \
  ; do \
    printf -- "%b" "#!/usr/bin/env sh\n/root/.acme.sh/acme.sh --${verb} --config-home /acme.sh \"\$@\"" >/usr/local/bin/--${verb} && chmod +x /usr/local/bin/--${verb} \
  ; done

RUN printf "%b" '#!'"/usr/bin/env sh\n \
if [ \"\$1\" = \"daemon\" ];  then \n \
 trap \"echo stop && killall crond && exit 0\" SIGTERM SIGINT \n \
 crond && while true; do sleep 1; done;\n \
else \n \
 exec -- \"\$@\"\n \
fi" >/entry.sh && chmod +x /entry.sh

VOLUME /acme.sh


# Add shell script to stage Docker secrets
COPY stage-env.sh /usr/local/bin/stage-env.sh
RUN chmod +x /usr/local/bin/stage-env.sh

# Add logrotate configuration
COPY acmelog /etc/logrotate.d/acmelog
RUN chmod 644 /etc/logrotate.d/acmelog && chown root:root /etc/logrotate.d/acmelog

# Override entrypoint with custom script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Execute default command of parent image
CMD ["--help"]