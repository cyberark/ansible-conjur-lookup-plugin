# Ansible Lookup Plugin

This Ansible plugin provides the ability to look up Conjur values in playbooks. It supports Conjur v4 and v5.

Based on the Ansible controlling host's identity, secrets can be retrieved securely using this plugin. This approach provides a simple alternative to the Ansible Vault, but usage of this plugin is recommended only as part of a soft migration to Conjur in existing Ansible playbooks, and efforts should be made to migrate to [Summon](https://github.com/cyberark/summon) as soon as practically possible.

**Note**: For Conjur v5, this plugin is included with Ansible >= 2.5.0.0. v4 support will be available soon.

To assign machine identity to nodes being controlled by ansible, see the [Conjur Ansible Role](https://github.com/cyberark/ansible-role-conjur/).

## Required Reading

* To learn more about Conjur, give it a [try](https://www.conjur.org/get-started/try-conjur.html)
* To learn more about how Conjur can be integrated with Ansible, visit the [Integration Documentation](https://www.conjur.org/integrations/ansible.html)
* To learn more about Summon, the tool that lets you execute applications with secrets retrieved from Conjur, visit the [Summon Webpage](https://cyberark.github.io/summon/)
* To learn more about other ways you can integrate with Conjur, visit our pages on the [CLI](https://developer.conjur.net/cli), [API](https://developer.conjur.net/clients), and [Integrations](https://www.conjur.org/integrations/)

## Installation

Install the Conjur role using the following syntax:

```sh-session
$ ansible-galaxy install cyberark.conjur-lookup-plugin
```

## Requirements

* A running Conjur service that is accessible from the Ansible controlling host.
* A Conjur identity on the Ansible controlling host (to accomplish this, it's recommended to use the [CLI to log in](https://developer.conjur.net/reference/services/authentication/login.html), or run the [Ansible role](https://github.com/cyberark/ansible-role-conjur/) on the host as a one-time action ahead of running your playbooks).
* Ansible >= 2.3.0.0

## Usage

Using environment variables:
```shell
export CONJUR_ACCOUNT="orgaccount"
#export CONJUR_VERSION="4"
export CONJUR_APPLIANCE_URL="https://conjur-appliance"
export CONJUR_CERT_FILE="/path/to/conjur_certficate_file"
export CONJUR_AUTHN_LOGIN="host/host_indentity"
export CONJUR_AUTHN_API_KEY="host API Key"
```
**Note**: By default the lookup plugin uses the Conjur 5 API to retrieve secrets. If using Conjur v4, set the environment variable `CONJUR_VERSION` set to `4`. You can provide it by uncommenting the relevant line above.


Playbook:
```yml
- hosts: servers
  roles:
    - role: cyberark.conjur-lookup-plugin
  tasks:
    - name: Retrieve secret with master identity
      vars:
        super_secret_key: {{ lookup('retrieve_conjur_variable', 'path/to/secret') }}
      shell: echo "Yay! {{super_secret_key}} was just retrieved with Conjur"
```

## Recommendations

* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. The Ansible uses the permissions of the user that runs it.

## License

Apache 2
