#!/bin/bash -ex
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

github_username=$1
github_useremail=$2
github_password=$3
deploy_type=${4:-openlab}
vault_password=$5

local_clouds_file=/etc/openstack/clouds.yaml
nodepool_file=~/inotify/labkeeper/etc/nodepool/${deploy_type}-nodepool.yaml.j2
clouds_file=~/inotify/labkeeper/etc/nodepool/${deploy_type}-clouds.yaml.j2
secrets_file=~/inotify/labkeeper/etc/nodepool/clouds-secrets.yaml

function pull_and_config_labkeeper()
{
    if [ ! -d ~/inotify/ ];then
        mkdir inotify
    fi
    if [ ! -d ~/inotify/labkeeper/ ];then
        echo "pull labkeeper repo"
        git clone https://github.com/theopenlab/labkeeper ~/inotify/labkeeper
        echo "clone labkeeper repo success!"
        cd ~/inotify/labkeeper
        git config user.name ${github_username}
        git config user.email ${github_useremail}
        echo "pull and config labkeeper success!"
    fi
    echo "The repo labkeeper is already there!"
}

# no need to enter username and password after config below when exec cmd 'git clone'
touch ~/.git-credentials
echo "https://${github_username}:${github_password}@github.com" > ~/.git-credentials
git config --global credential.helper store

pull_and_config_labkeeper

# git checkout a new branch
cd ~/inotify/labkeeper/
git pull
modify_time=`date +%Y%m%d%H%M`
branch_name="update${modify_time}"
message="Sync_update_${modify_time}_modified_by_${github_username}"
git checkout -b ${branch_name}

# handle the file nodepool.yaml
echo "sync modify the file $nodepool_file"
# delete the lines from 'labels:' to end
sed -i '/^labels/,$d' $nodepool_file
# copy the lines of /etc/nodepool/nodepool.yaml from 'labels' to end
sed -n '/^labels/,$p' /etc/nodepool/nodepool.yaml >> $nodepool_file

# handle the file {deploy_type}-clouds.yaml.j2 and clouds-secrets.yaml
echo "$vault_password" > vault-password.txt
cp $local_clouds_file clouds_temp.yaml
cp $secrets_file secrets_temp.yaml

# decrypt the secrets in clouds-secrets.yaml
for key in `cat $secrets_file | shyaml keys`
do
    echo "$key: `cat  $secrets_file | shyaml get-value $key | ansible-vault decrypt`" >> old_secrets_decrypted.yaml
done

python /home/ubuntu/modify_files.py

sed -i '1i ---' secrets_temp.yaml
mv clouds_temp.yaml $clouds_file
mv secrets_temp.yaml $secrets_file
# rm the temp files
rm old_secrets_decrypted.yaml

is_modified="`git status |grep modified`"
if [[ $is_modified ]];then
    git add .
    git commit -m "${message}"
    git push origin ${branch_name}
    # using hub to create pull-request
    export GITHUB_USER=${github_username}
    export GITHUB_PASSWORD=${github_password}
    hub pull-request -m "${message}"
    echo "Create pull request to theopenlab/labkeeper success!"
    git checkout master
    git branch -D ${branch_name}
fi
