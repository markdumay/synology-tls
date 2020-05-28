# Synology TLS (work in progress)


<!-- Tagline -->
<p align="center">
    <b>Automatically update Let's Encrypt wildcard certificates for Synology NAS</b>
    <br />
</p>


<!-- Badges -->
<p align="center">
    <a href="https://github.com/markdumay/synology-tls/commits/master" alt="Last commit">
        <img src="https://img.shields.io/github/last-commit/markdumay/synology-tls.svg" />
    </a>
    <a href="https://github.com/markdumay/synology-tls/issues" alt="Issues">
        <img src="https://img.shields.io/github/issues/markdumay/synology-tls.svg" />
    </a>
    <a href="https://github.com/markdumay/synology-tls/pulls" alt="Pulls">
        <img src="https://img.shields.io/github/issues-pr-raw/markdumay/synology-tls.svg" />
    </a>
    <a href="https://github.com/markdumay/synology-tls/blob/master/LICENSE" alt="License">
        <img src="https://img.shields.io/github/license/markdumay/synology-tls.svg" />
    </a>
</p>

<!-- Table of Contents -->
<p align="center">
  <a href="#about">About</a> •
  <a href="#built-with">Built With</a> •
  <a href="#prerequisites">Prerequisites</a> •
  <a href="#testing">Testing</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#donate">Donate</a> •
  <a href="#license">License</a>
</p>


## About
[Synology][synology_url] is a popular manufacturer of Network Attached Storage (NAS) devices. It provides a web-based user interface called Disk Station Manager (DSM). Building upon [acme.sh][acmesh_url], *Synology TLS* simplifies the setup of secure access to DSM via HTTPS. It uses Let's Encrypts to automatically issue and renew TLS certificates for a specific internet domain. By using CloudFlare, Synology TLS allows the NAS to stay behind a firewall without exposing ports to the public internet. The package is set up as a Docker image to simplify deployment and uses Docker Swarm secrets to secure credentials.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [acme.sh][acmesh_url] - A pure Unix shell script to automatically issue & renew free certificates from Let's Encrypt
* [Docker][docker_url] - Container platform (including Swarm and Compose)


## Prerequisites
Synology TLS can run on any Docker-capable host. The setup has been tested locally on macOS Catalina and a Synology NAS running DSM 6.2. Other prerequisites are:

* **A registered domain name is required** - A domain name is required to configure SSL certificates that will enable secure traffic to your Synology NAS. You should have the ability to configure DNS entries for your domain too.

* **Docker Compose and Docker Swarm are required** - Synology TLS is to be deployed as Docker container in swarm mode to enable Docker *secrets*. This [reference guide][swarm_init] explains how to initialize Docker Swarm on your host.

* **A CloudFlare account and token are required** - Synology TLS uses CloudFlare to automate the DNS configuration. CloudFlare offers a free plan that should suffice for most needs. Follow the wizard `+ Add a Site` on the homepage to let CloudFlare manage the DNS of your domain. Once done, you will need to set up an API Token for Synology TLS too. From CloudFlare's homepage, go to `My Profile ➡ API Tokens`. Add a new token with `Zone/Zone/Edit` and `Zone/DNS/Edit` permissions and include your domain in the 'Zone Resources'. Make a safe copy of the token, as it will be displayed only once.

* **A Synology administrative account is required** - Synology TLS uses an administrative account to deploy the certificates automatically. It is recommended to set up a dedicated account for the renewal of certificates only. You can add a user in DSM via `Control Panel ➡ User ➡ Create`. Make sure the account is a member of the Administrators group. You can set all shared-folder permissions to 'No access' and all application permissions to 'Deny'.


## Testing
It is recommended to test the services locally before deploying them to your NAS. Running the service with `docker-compose` greatly simplifies validating everything is working as expected. Below four steps will allow you to run the services on your local machine and validate it is working correctly.

### Step 1 - Clone the Repository
The first step is to clone the repository to a local folder. Assuming you are in the working folder of your choice, clone the repository files. Git automatically creates a new folder `synology-tls` and copies the files to this directory. Now change your working folder to be prepared for the next steps.

```console
git clone https://github.com/markdumay/synology-tls.git
cd synology-tls
```

### Step 2 - Create Docker Secret Files
As Docker-compose does not support external Swarm secrets, we will create local secret files for testing purposes. The credentials are stored as plain text, so this is not recommended for production. Replace the values with your CloudFlare (`CF_` prefix) and Synology (`SYNO_`) credentials accordingly (see <a href="#prerequisites">prerequisites</a>).

```console
mkdir secrets
printf mail@example.com > secrets/CF_Email.txt
printf password > secrets/CF_Token.txt
printf admin > secrets/SYNO_Username.txt
printf password > secrets/SYNO_Password.txt
```

### Step 3 - Update the Environment Variables
The `docker-compose.yml` file uses environment variables to simplify the configuration. You can use the sample file in the repository as a starting point.

```console
mv sample.env .env
```

The `.env` file specifies eight variables. Adjust them as needed:

* **CRON_SCHEDULE** - Defines the schedule for automated renewal and deployment of the certificates. The job also updates the acme.sh script. [Crontab guru][crontab_guru] is an excellent help for defining cron schedules. The default value `0 2 * * *` validates the certificates at 2 am daily.

* **DOMAIN** - Replace this with your domain name (e.g. `example.com`).

* **STAGE** - Options are `staging` or `production`. Use `staging` for testing purposes to avoid hitting rate limits from Let's Encrypt.

* **FORCE_RENEW** - If `true`, forces renewal of the certificates regardless of whether they are still valid. The default value is `false`.

* **DEPLOY_HOOK** - The `acme.sh` script supports up to 20 different deployment hooks. Synology TLS defaults to `synology_dsm`. Refer to the [wiki][acmesh_deploy] to see the notes on supporting two-factor authentication for your Synology account.

* **SYNO_Certificate** - Defines the description to be shown in DSM's `Control Panel ➡ Security ➡ Certificate`.

* **SYNO_Hostname** - Refers to the local address of your Synology NAS. Replace this with the local IP address of your NAS. You can find the address in DSM at `Control Panel ➡ Info Center ➡ Network` under `LAN 1`.

* **SYNO_Port** - Captures the HTTP port DSM is listening on, the default value is `5000`. You can find the current value in DSM under `Control Panel ➡ Network ➡ DSM Settings`.


### Step 4 - Run with Docker Compose
Test the Docker service with `docker-compose up`.

```console
docker-compose up
```

After pulling the image from the Docker Hub, you should see several messages. Below excerpt shows the key messages per section.

#### Booting of the service
During boot, Synology TLS replaces the cronjob of acme.sh with a custom job following the schedule in `.env`. The cronjob writes a log file to `'/var/log/acme.log'`.
```
acme_1 | Removing cron job
acme_1 | LE_WORKING_DIR='/root/.acme.sh'
acme_1 | Using stage ACME_DIRECTORY: https://acme-staging-v02.api.letsencrypt.org/directory
acme_1 | Adding custom cron job at '* 2 * * *'
acme_1 | View the cron log in '/var/log/acme.log'
```

#### Updating of acme.sh
The acme.sh script is updated regularly. The latest version is downloaded during booting and will be refreshed by cron too.
```
acme_1 | Installing from online archive.
acme_1 | Installed to /root/.acme.sh/acme.sh
acme_1 | Upgrade success!
```

#### Conducting DNS-01 check
Synology TLS uses a DNS-01 Challenge so Let's Encrypt can validate ownership of your domain. This setup prevents having to expose your NAS to the public internet. The DNS configuration is automated using CloudFlare. By default, Synology TLS requests the main certificate and a wildcard certificate for your domain.
```
acme_1 | Create account key ok.
acme_1 | Multi domain='DNS:example.com,DNS:*.example.com'
acme_1 | Let's check each dns records now. Sleep 20 seconds first.
acme_1 | Verifying: example.com
acme_1 | Success
acme_1 | Verifying: *.example.com
acme_1 | Success
```

#### Downloading Let's Encrypt certificates
With the DNS-01 challenge passed, Synology TLS then downloads the certificates. The certificates and keys are stored in the mounted folder `data/acme/example.com`.
```
acme_1 | Download cert, Le_LinkCert: https://acme-staging-v02.api.letsencrypt.org/acme/cert/xxx
acme_1 | Cert success.
acme_1 | Your cert is in  /acme.sh/example.com/example.com.cer 
```

#### Deploying the certificates to your NAS
As a final step, the certificates are automatically deployed to your Synology NAS. 
```
acme_1 | Logging into localhost:5000
acme_1 | Upload certificate to the Synology DSM
acme_1 | Success
```

By default, Synology TLS runs in the background as Daemon and validates the certificates in a daily cron job. The cron log can be viewed with the following command:

```
docker exec synology-tls_acme_1 /bin/sh -c 'cat /var/log/acme.log'
```


## Deployment
The steps for deploying in production are slightly different than for local testing. Below four steps highlight the changes compared to the testing walkthrough.


### Step 1 - Clone the Repository
*Unchanged*


### Step 2a - Create Docker Swarm Secrets
Instead of file-based secrets, you will now create secure secrets. Docker secrets can be easily created using pipes. Do not forget to include the final `-`, as this instructs Docker to use piped input. Update the credentials as needed.

```console
printf mail@example.com | docker secret create CF_Email -
printf password | docker secret create CF_Token -
printf admin | docker secret create SYNO_Username -
printf password | docker secret create SYNO_Password -
```

If you do not feel comfortable copying secrets from your command line, you can use the wrapper `create_secret.sh`. This script prompts for a secret and ensures sensitive data is not displayed in your console.

```console
./create_secret.sh CF_Email
./create_secret.sh CF_Token
./create_secret.sh SYNO_Username
./create_secret.sh SYNO_Password
```

### Step 2b - Update the Docker Compose File
The `docker-compose.yml` in the repository defaults to set up for local testing. Update the `secrets` section to use Docker secrets instead of local files.

```Dockerfile
secrets:
    CF_Email:
        external: true
    CF_Token:
        external: true
    SYNO_Username:
        external: true
    SYNO_Password:
        external: true
```

### Step 3 - Update the Environment Variables
*Unchanged, however, set STAGE to production once everything is working properly*


### Step 4 - Run with Docker Stack
Unlike Docker Compose, Docker Stack does not automatically create local folders. Create an empty folder for the `acme.sh` data and log data. Next, deploy the Docker Stack using `docker-compose` as input. This ensures the environment variables are parsed correctly.

```console
mkdir -p data/acme
mkdir -p data/log
docker-compose config | docker stack deploy -c - synology-tls
```

Run the following command to inspect the status of the Docker Stack.

```console
docker stack services synology-tls
```

You should see the value `1/1` for `REPLICAS` for the Synology TLS service if the stack was initialized correctly. It might take a while before the services are up and running, so simply repeat the command after a few minutes if needed.

```
ID  NAME                MODE        REPLICAS    IMAGE                               PORTS
*** synology-tls        replicated  1/1         markdumay/synology-tls:2.8.6
```

You can view the service log with `docker service logs <service-name>` once the service is up and running. Refer to the paragraph <a href="#step-4---run-with-docker-compose">Step 4 - Run with Docker Compose</a> for validation of the logs.

Debugging swarm services can be quite challenging. If for some reason your service does not initiate properly, you can get its task ID with `docker service ps <service-name>`. Running `docker inspect <task-id>` might give you some clues to what is happening. Use `docker stack rm synology-tls` to remove the docker stack entirely.


## Usage
The installed certificate can be viewed in DSM by navigating to `Control Panel ➡ Security ➡ Certificate`. Click on the button `Configure` to assign the certificate to your services.


## Contributing
1. Clone the repository and create a new branch 
    ```
    $ git checkout https://github.com/markdumay/synology-tls.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes

## Credits
Synology TLS is inspired by the following code repositories and blog articles:
* Neilpang - owner and maintainer of [acme.sh][acmesh_url]
* Markus Lippert - [Automatically renew Let's Encrypt certificates on Synology NAS using DNS-01 challenge][markus_renew]
* xFelix - [Synology Letsencrypt DNS-01 cert issue and install][xfelix_letsencrypt]
* Luka Manestar - [Let's Encrypt + Docker = wildcard certs][luka_wildcard]


## Donate
<a href="https://www.buymeacoffee.com/markdumay" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-orange.png" alt="Buy Me A Coffee" style="height: 51px !important;width: 217px !important;"></a>

## License
<a href="https://github.com/markdumay/synology-tls/blob/master/LICENSE" alt="License">
    <img src="https://img.shields.io/github/license/markdumay/synology-tls.svg" />
</a>

Copyright © [Mark Dumay][blog]



<!-- MARKDOWN PUBLIC LINKS -->
[acmesh_deploy]: https://github.com/acmesh-official/acme.sh/wiki/deployhooks
[acmesh_url]: https://acme.sh
[crontab_guru]: https://crontab.guru
[docker_url]: https://docker.com
[luka_wildcard]: https://www.blackvoid.club/lets-encrypt-docker-wild-card-certs/
[markus_renew]: https://lippertmarkus.com/2020/03/14/synology-le-dns-auto-renew/
[synology_url]: https://www.synology.com
[swarm_init]: https://docs.docker.com/engine/reference/commandline/swarm_init/
[xfelix_letsencrypt]: https://www.xfelix.com/2017/06/synology-letsencrypt-dns-01-cert-issue-and-install/

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/synology-tls.git