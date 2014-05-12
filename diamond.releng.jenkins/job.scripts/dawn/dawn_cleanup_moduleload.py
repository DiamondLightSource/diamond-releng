###
### Generate a shell script to delete old published versions of the Dawn product
###
### The script assumes that the directory ${backup_location} holds the published versions, as
### directories immediately below it, one per version published per platform
###
### Old versions are deleted, subject to the following rules:
### (1) keep all versions that are pointed to be a symlink, no matter how old they are
### (1) keep at least ${minimum_number_of_versions_to_keep}
### (2) keep ${keep_all_versions_newer_than_days}
###

from __future__ import print_function

import datetime
import os
import stat
import sys

def generate_cleanup_script():

    backup_location = os.environ['publish_module_load_directory_for_type']
    platform = os.environ['platform']
    minimum_number_of_versions_to_keep = int(os.environ['publish_module_load_minimum_number_of_versions_to_keep'])
    keep_all_versions_newer_than_days = int(os.environ['publish_module_load_keep_all_versions_newer_than_days'])

    # generate the shell commands required to delete old backups
    print('''\
cleanup_backups () {
  cd %(backup_location)s'''
    % {'backup_location': backup_location,
       'minimum_number_of_versions_to_keep': minimum_number_of_versions_to_keep,
       'keep_all_versions_newer_than_days': keep_all_versions_newer_than_days})

    targets_of_symbolic_links = []
    for backupdir in sorted(os.listdir(backup_location), reverse=True):
        backupdir_path = os.path.join(backup_location, backupdir)
        backupdir_stat = os.lstat(backupdir_path)
        if stat.S_ISLNK(backupdir_stat.st_mode):
            targets_of_symbolic_links.append(os.readlink(backupdir_path))
    backups_kept_count = 0
    today_date = datetime.date.today()
    for backupdir in sorted(os.listdir(backup_location), reverse=True):
        backupdir_path = os.path.join(backup_location, backupdir)
        backupdir_stat = os.lstat(backupdir_path)
        if not stat.S_ISDIR(backupdir_stat.st_mode):
            continue
        if not backupdir.endswith('-%s' % platform):
            continue
        backupdir_date = datetime.date.fromtimestamp(backupdir_stat.st_mtime)
        if ((backups_kept_count < minimum_number_of_versions_to_keep) or
            (backupdir in targets_of_symbolic_links) or
            ((today_date - backupdir_date).days < keep_all_versions_newer_than_days)):
            print('  : keeping       %s' % backupdir_path)
            backups_kept_count += 1
        else:
            print('  ${chmod} -R u+w %s' % backupdir_path)
            print('  ${rm} -rf       %s' % backupdir_path)
    print('''\
}
cleanup_backups
'''
    )

###############################################################################
# Command line processing                                                     #
###############################################################################

if __name__ == '__main__':
    generate_cleanup_script()

