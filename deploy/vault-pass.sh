#!/bin/sh
# передаём пароль для ansible-vault из CI-переменной ANSIBLE_VAULT_PASSWORD
set -eu
printf '%s\n' "${ANSIBLE_VAULT_PASSWORD:?ANSIBLE_VAULT_PASSWORD is not set}"
