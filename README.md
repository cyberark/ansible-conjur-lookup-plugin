# Ansible Lookup Plugin

This Ansible plugin provides the ability to look up Conjur values in playbooks. It supports Conjur v4 and v5.

**Note**: For v5, this capability is included with Ansible >= 4.5.0.0 (v4 support coming soon).

Based on the controlling host's identity, secrets can then be retrieved securely using the
`retrieve_conjur_variable` lookup plugin. Usage of this plugin is recommended only as part of a soft migration to Conjur in existing Ansible playbooks,
and efforts should be made to migrate to [Summon](https://github.com/cyberark/summon) as soon as practically possible.

To assign machine identity to nodes being controlled by ansible, see the [Conjur Ansible Role](https://github.com/cyberark/ansible-role-conjur/).

Additionally, [Summon](https://github.com/cyberark/summon), the
[Conjur CLI](https://github.com/cyberark/conjur-cli), and the
[Conjur API](https://www.conjur.org/api.html)
can also be used to retrieve secrets from a host with Conjur identity.

## Installation

Install the Conjur role using the following syntax:

```sh-session
$ ansible-galaxy install cyberark.conjur-lookup-plugin
```

## Requirements

A running Conjur service that is accessible from the Ansible host.

To assign a conjur identity to the Ansible controlling host, it's recommended to use the [CLI to log in](https://developer.conjur.net/reference/services/authentication/login.html),
or run the [Ansible role](https://github.com/cyberark/ansible-role-conjur/) on the host as a one-time action ahead of running your playbooks.

## Overview

The lookup plugin uses the control node’s identity to retrieve secrets from Conjur and provide them to the relevant playbook. The control node has execute permission on all relevant variables. It retrieves values from Conjur at runtime.  The retrieved secrets are inserted by the playbook where needed before the playbook is passed to the remote nodes.  

This approach provides a simple alternative to the Ansible Vault. With only minor changes to an existing playbook, you can leverage these Conjur features:

* The Conjur RBAC model provides users and groups with access to manage and rotate secrets (in contrast to sharing an encryption key).
* Moving secrets outside of Ansible Vault enables them to be used by a wide range of different systems.
* Enterprise Conjur provides automated rotators that you can easily configure with a few statements added to policy.

A disadvantage to the lookup plugin approach is that the control node requires access to all credentials fetched on behalf of the remote nodes, making the control node a potential high-value target.  In many production environments, a single source of privilege may not be acceptable. There is also a potential risk of accidentally leaking retrieved secrets to nodes.  All nodes targeted through a playbook will have access to secrets granted to that playbook.  

Despite the control node being a single source of access, note the following:

* You can mitigate the risk with thoughtful network design and by paying extra attention to securing the control node.  
* The solution does not store secrets on the control node.  The control node simply passes the values onto the remote nodes in a playbook through SSH, and the secrets disappear along with the playbook at the end of execution.

The lookup plugin has the additional advantage of being quite simple and quick to implement. It   may be sufficient for smaller installations and for testing and development environments. Try this approach first to learn about Conjur and the Ansible conjur role.

## Usage

Conjur's `retrieve_conjur_variable` lookup plugin provides a means for retrieving secrets from Conjur for use in playbooks.

*Note that by default the lookup plugin uses the Conjur 5 API to retrieve secrets. To use Conjur 4 API, set an environment CONJUR_VERSION="4".*

Since lookup plugins run in the Ansible host machine, the identity that will be used for retrieving secrets
are those of the Ansible host. Thus, the Ansible host requires elevated privileges, access to all secrets that a remote node may need.

The lookup plugin can be invoked in the playbook's scope as well as in a task's scope.

### Example Playbook
Using environment variables:
```shell
export CONJUR_ACCOUNT="orgaccount"
export CONJUR_VERSION="4"
export CONJUR_APPLIANCE_URL="https://conjur-appliance"
export CONJUR_CERT_FILE="/path/to/conjur_certficate_file"
export CONJUR_AUTHN_LOGIN="host/host_indentity"
export CONJUR_AUTHN_API_KEY="host API Key"
```

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
      register: foo
    - debug: msg="the echo was {{ foo.stdout }}"

```

## Recommendations

* Add `no_log: true` to each play that uses sensitive data, otherwise that data can be printed to the logs.
* Set the Ansible files to minimum permissions. The Ansible uses the permissions of the user that runs it.

## License

Apache 2
