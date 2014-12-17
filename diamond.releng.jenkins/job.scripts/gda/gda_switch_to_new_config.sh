set -o verbose

if [[ -z "${new_config_repo_parent}" ]]; then
    echo "ERROR: $""{new_config_repo_parent} not set - exiting"
    exit 1
fi
if [[ -z "${need_to_clone}" ]]; then
    echo "ERROR: $""{need_to_clone} not set - exiting"
    exit 1
fi

# ***************************"
# * Processing gda-core.git *"
# ***************************"
repo=gda-core
cd ${new_config_repo_parent}
if [[ "${need_to_clone}" == "true" ]]; then
    rm -rf ${repo}.git
    # clone the repo (this will checkout the master branch)
    git clone ssh://dascgitolite@dasc-git.diamond.ac.uk/gda/${repo}.git ${repo}.git
fi
cd ${repo}.git

# make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
git checkout master
git branch -D local-GDA-6009b || true
git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b
git checkout local-GDA-6009b
git status

# rebase the local branch on top of master
git rebase --verbose master 
git status

# now try merging in the "final" changes
git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
git commit -m "GDA-6009 complete switch to new configuration layout"
git status

# see what we have in advance of master
git log master^..

# *******************************"
# ** Processing gda-diamond.git *"
# ******************************"
repo=gda-diamond
cd ${new_config_repo_parent}
if [[ "${need_to_clone}" == "true" ]]; then
    rm -rf ${repo}.git
    # clone the repo (this will checkout the master branch)
    git clone ssh://dascgitolite@dasc-git.diamond.ac.uk/gda/${repo}.git ${repo}.git
fi
cd ${repo}.git

# make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
git checkout master
git branch -D local-GDA-6009b || true
git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b
git checkout local-GDA-6009b
git status

# rebase the local branch on top of master
git rebase --verbose master 
git status

# no "final" changes to merge in 
#git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
#git commit -m "GDA-6009 complete switch to new configuration layout"
#git status

# see what we have in advance of master
git log master^..

# *******************************"
# ** Processing gda-mt.git *"
# ******************************"
repo=gda-mt
cd ${new_config_repo_parent}
if [[ "${need_to_clone}" == "true" ]]; then
    rm -rf ${repo}.git
    # clone the repo (this will checkout the master branch)
    git clone ssh://dascgitolite@dasc-git.diamond.ac.uk/gda/${repo}.git ${repo}.git
fi
cd ${repo}.git

# make a new local branch - we'll do our changes in this, to avoid any risk of pushing something back to the remote
git checkout master
git branch -D local-GDA-6009b || true
git branch -vv --no-track local-GDA-6009b remotes/origin/GDA-6009b-group
git checkout local-GDA-6009b
git status

# rebase the local branch on top of master
git rebase --verbose master 
git status

# now try merging in the "instance" changes
# git merge --verbose --squash remotes/origin/GDA-6009b-b24  <-- the replay version
git merge --verbose --squash remotes/origin/GDA-6009-b24-working-prototype
git commit -m "GDA-6009 new configuration layout changes for group"
git status

# now try merging in the "final" changes
git merge --verbose --squash remotes/origin/GDA-6009-final-cleanup
git commit -m "GDA-6009 complete switch to new configuration layout"
git status

# see what we have in advance of master
git log master..

set +o verbose
#set +o xtrace
