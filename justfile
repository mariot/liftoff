set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

vm-ip vm_name="xtm-test":
    @multipass info "{{ vm_name }}" | awk '/IPv4/{print $2; exit}'

vm-create vm_name="xtm-test" cpus="4" memory="10G" disk="50G" image="lts" ssh_pubkey=env_var_or_default("SSH_PUBKEY", "~/.ssh/id_rsa.pub"):
    @test -f "{{ ssh_pubkey }}" || (echo "SSH public key not found: {{ ssh_pubkey }}" >&2; exit 1)
    @if multipass info "{{ vm_name }}" >/dev/null 2>&1; then \
      echo "VM '{{ vm_name }}' already exists."; \
    else \
      multipass launch --name "{{ vm_name }}" --cpus "{{ cpus }}" --memory "{{ memory }}" --disk "{{ disk }}" "{{ image }}"; \
    fi
    @PUBKEY="$(cat "{{ ssh_pubkey }}")"; \
      multipass exec "{{ vm_name }}" -- bash -lc "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && grep -qxF \"$PUBKEY\" ~/.ssh/authorized_keys || echo \"$PUBKEY\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    @echo "VM IP: $(multipass info "{{ vm_name }}" | awk '/IPv4/{print $2; exit}')"

inventory-write vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa"):
    @VM_IP="$(multipass info "{{ vm_name }}" | awk '/IPv4/{print $2; exit}')"; \
      test -n "$VM_IP" || (echo "Could not determine VM IP for {{ vm_name }}" >&2; exit 1); \
      mkdir -p "$(dirname "{{ inventory_file }}")"; \
      printf 'all:\n  children:\n    xtm_servers:\n      hosts:\n        {{ vm_name }}:\n          ansible_host: %s\n          ansible_user: ubuntu\n          ansible_ssh_private_key_file: {{ ssh_key }}\n' \
        "$VM_IP" \
        > "{{ inventory_file }}"
    @echo "Wrote {{ inventory_file }}"

deploy vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa"):
    @just inventory-write "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
    ansible-playbook -i "{{ inventory_file }}" site.yml

deploy-opencti vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa"):
    @just inventory-write "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
    ansible-playbook -i "{{ inventory_file }}" site.yml -e xtm_deploy_target=opencti

deploy-openaev vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa"):
    @just inventory-write "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
    ansible-playbook -i "{{ inventory_file }}" site.yml -e xtm_deploy_target=openaev

deploy-output vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa") output_file="ansible-output.log":
    @just inventory-write "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
    ansible-playbook -i "{{ inventory_file }}" site.yml 2>&1 | tee "{{ output_file }}"

env-pull vm_name="xtm-test" inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa") env_file=".env.multipass":
    @just inventory-write "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
    ansible -i "{{ inventory_file }}" xtm_servers -b -m ansible.builtin.fetch -a "src=/opt/xtm/.env dest={{ env_file }} flat=true"

up vm_name="xtm-test" cpus="4" memory="10G" disk="50G" image="lts" ssh_pubkey=env_var_or_default("SSH_PUBKEY", "~/.ssh/id_rsa.pub") inventory_file="inventory/hosts.multipass.yml" ssh_key=env_var_or_default("SSH_KEY_FILE", "~/.ssh/id_rsa"):
    @just vm-create "{{ vm_name }}" "{{ cpus }}" "{{ memory }}" "{{ disk }}" "{{ image }}" "{{ ssh_pubkey }}"
    @just deploy "{{ vm_name }}" "{{ inventory_file }}" "{{ ssh_key }}"
