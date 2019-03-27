import commands
from ruamel.yaml import YAML

yaml = YAML()
secrets = dict()
clouds_temp_file = 'clouds_temp.yaml'
secrets_temp_file = 'secrets_temp.yaml'
old_secrets_decrypted_file = 'old_secrets_decrypted.yaml'

# sync the update for file clouds.yaml, to hidden username and password, like {{ otc_username }}
with open(clouds_temp_file) as f:
    content = yaml.load(f)
    cloud_names = content['clouds'].keys()
    for cloud in cloud_names:
        cloud_username = cloud + '_username'
        cloud_password = cloud + '_password'
        secrets[cloud_username] = content['clouds'][cloud]['auth']['username']
        secrets[cloud_password] = content['clouds'][cloud]['auth']['password']
        content['clouds'][cloud]['auth']['username'] = '{{ ' + cloud_username + ' }}'
        content['clouds'][cloud]['auth']['password'] = '{{ ' + cloud_password + ' }}'

with open(clouds_temp_file, 'w') as nf:
    yaml.dump(content, nf)

# sync the update for file clouds-secrets.yaml based on the /etc/openstack/clouds.yaml
encrypt_cmd = 'ansible-vault encrypt_string '
decrypt_cmd = 'ansible-vault decrypt '

with open(secrets_temp_file) as secret_f:
    secrets_encrypted = yaml.load(secret_f)

with open(old_secrets_decrypted_file) as f:
    old_secrets_decrypted = yaml.load(f)

diff_keys = []
for k,v in old_secrets_decrypted.items():
    if k not in secrets:
        del secrets_encrypted[k]
    else:
        if v != secrets[k]:
            del secrets_encrypted[k]
            diff_keys.append(k)
print diff_keys

with open(secrets_temp_file, 'w') as nf:
    yaml.dump(secrets_encrypted, nf)

with open(secrets_temp_file) as secret_f:
    data = yaml.load(secret_f)

keys_added = [item for item in secrets.keys() if item not in data.keys()]
print keys_added
write_lines = []
for key in keys_added:
    value = secrets[key]
    cmd = 'ansible-vault encrypt_string ' + value
    encrypt_var = commands.getoutput(cmd) + '\n'
    write_lines.append(key + ': ' + commands.getoutput(cmd) + '\n')

with open(secrets_temp_file, 'a') as f:
    f.writelines(write_lines)
