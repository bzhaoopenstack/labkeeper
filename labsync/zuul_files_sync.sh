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

online_file=~/inotify/labkeeper/etc/zuul/${deploy_type}-main.yaml

set -e

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

# the default path of cron is /usr/bin:/bin
export PATH=/usr/local/bin:$PATH

# no need to enter username and password after config below when exec cmd 'git clone'
touch ~/.git-credentials
# password of theopenlab-ci has special char !@#, to encode it
pass_urlencode=`python -c "from urllib import quote;import sys;print quote(sys.argv[1])" ${github_password}`
echo "https://${github_username}:$pass_urlencode@github.com" > ~/.git-credentials
git config --global credential.helper store

pull_and_config_labkeeper

cd ~/inotify/labkeeper/
git checkout master

# maybe some errors happened last time, the branch wont be clean
is_clean="`git status |grep clean`"
if [[ -n $is_clean ]];then
    echo 'branch is clean!'
else
    echo 'branch is not clean!!'
    git reset --hard HEAD
fi
git pull
modify_time=`date +%Y%m%d%H%M`
branch_name="update${modify_time}"
message="[Zuul_Sync] Sync_${modify_time}_modified_by_${github_username}"
git checkout -b ${branch_name}
echo "copy file to labkeeper"
cp /etc/zuul/main.yaml $online_file

is_modified="`git status |grep modified`"
if [[ $is_modified ]];then
    git add $online_file
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
