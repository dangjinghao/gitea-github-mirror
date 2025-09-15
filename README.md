![Gitea Compatible](https://img.shields.io/badge/Gitea-compatible-green)
![GitHub Compatible](https://img.shields.io/badge/GitHub-compatible-green)
![API Tokens Required](https://img.shields.io/badge/API%20Tokens-required-blue)

# Gitea GitHub Mirror

> ℹ️ **Note**  
> A detailed tutorial is available at: [https://www.filipnet.de/gitea-github-mirror](https://www.filipnet.de/gitea-github-mirror)

This project provides an automation script to mirror repositories from **GitHub** into **Gitea** organizations. It leverages the Github and Gitea REST API for repository migration, including support for authentication and mirror intervals.

- Further information and usage details can be found in the tutorial:  
  https://www.filipnet.de/gitea-github-mirror

- The project’s source code is available on GitHub:  
  https://github.com/filipnet/gitea-github-mirror

## Table of contents

<!-- TOC -->

- [Gitea GitHub Mirror](#gitea-github-mirror)
  - [Table of contents](#table-of-contents)
  - [Features](#features)
  - [Getting Started](#getting-started)
    - [Install the script](#install-the-script)
    - [Create the configuration file](#create-the-configuration-file)
    - [Test the script in dry-run mode](#test-the-script-in-dry-run-mode)
    - [Update repository list](#update-repository-list)
    - [Example cron job](#example-cron-job)
    - [Update the script](#update-the-script)
  - [Good References](#good-references)
  - [Contributions](#contributions)
  - [License](#license)

<!-- /TOC -->

## Features

- **Mirror GitHub repos** directly into Gitea organizations
- **Automated repository creation** using the Gitea API
- **Support for authentication** with secure API tokens
- **Simple scripting** for automation workflows

## Getting Started

Follow these steps to set up the GitHub → Gitea mirroring script on a Linux host.

### Install the script

Clone the repository under `/opt` and make the script executable:

```bash
cd /opt
sudo git clone https://github.com/filipnet/gitea-github-mirror.git gitea-github-mirror
cd gitea-github-mirror
sudo chmod +x gitea-github-mirror.sh
```

### Create the configuration file

Copy the example configuration and edit it with your credentials:

```bash
cp gitea-github-mirror.conf.example gitea-github-mirror.conf
nano gitea-github-mirror.conf
```

Set the following:

```bash
GITHUB_OWNER="your-github-username-or-org"
GITHUB_TOKEN="your-github-personal-access-token"
GITEA_ORG="target-gitea-organization"
GITEA_URL="https://your.gitea.instance"
GITEA_USER="gitea-user-owning-the-token"
GITEA_TOKEN="your-gitea-api-token"
DRY_RUN=true          # true to test without creating mirrors, false to actually mirror
DEBUG=true            # true to enable verbose logging
MIRROR_INTERVAL=60    # interval in minutes between automatic mirror updates
FILTER_MODE="exclude" # "include" or "exclude" mode for repository selection
INCLUDE_REPOS=("repo1" "repo2") # list of repos to include (used only if FILTER_MODE="include")
EXCLUDE_REPOS=("repo3" "repo4") # list of repos to exclude (used only if FILTER_MODE="exclude")
```

### Test the script in dry-run mode

Run the script without making any changes:

```bash
./gitea-github-mirror.sh
```

If `DRY_RUN=true` is set in `gitea-github-mirror.conf`, the script will only print which repositories would be mirrored.### Update repository list

### Update repository list

When running the script, it will check which GitHub repositories already exist in the target Gitea organization.  
Repositories that already exist are **automatically skipped**.

```
[SKIP] weatherstation already exists in Gitea org github-mirror
```

If you create new repositories in GitHub and want to mirror them, you can either:

- **Rerun the script manually** after adding new repos, or
- **Automate updates with a cron job** to keep the mirror list in sync.

### Example cron job

Run the script every day at 2:00 AM:

```bash
0 2 * * * /opt/gitea-github-mirror/gitea-github-mirror.sh >> /var/log/gitea-github-mirror.log 2>&1
```

This will automatically check GitHub and create mirrors for any new repositories that don't yet exist in Gitea.

### Update the script

To update the `gitea-github-mirror` script and keep your local configuration:

```bash
cd /opt/gitea-github-mirror
Pull the latest changes from GitHub:
git pull
```

Thanks to .gitignore, your local gitea-github-mirror.conf file will not be affected or overwritten by the update.

## Good References

- [Gitea Documentation](https://docs.gitea.com) – official Gitea docs
- [Gitea API Reference](https://docs.gitea.com/api/) – official API reference

## Contributions

Contributions are welcome! Please open issues or submit pull requests to improve functionality, add features, or fix bugs. All improvements are appreciated.

## License

`gitea-github-mirror` is under the **BSD 3-Clause license** unless explicitly noted otherwise.
See the [LICENSE](./LICENSE) file for more details.

```

```

```

```
