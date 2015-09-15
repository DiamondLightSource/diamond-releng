#!/usr/bin/env python
# -*- coding: utf-8 -*-

###
### Generate a shell script to delete old published versions of the Dawn product
###
### Old versions are deleted, subject to the following rules:
### (1) only delete versions that are in a directory that contains a "cleanup.config" file (such directories must not be nested)
### (2) keep all versions that are pointed to be a symlink, no matter how old they are
### (3) keep at least "minimum_number_of_versions_per_platform_to_keep" (read from the config file)
### (4) keep "keep_all_versions_newer_than_days" (read from the config file)
###

from __future__ import absolute_import, division, print_function, unicode_literals  # make it easier if we ever move to Python 3
import ConfigParser
import datetime
import os
import stat
import sys
import time

PUBLISH_DIRECTORY_PARENTS = ('/dls_sw/apps/DawnDiamond', '/dls_sw/apps/DawnVanilla')

CLEANUP_SCRIPT_FILE_PATH = os.environ.get('CLEANUP_SCRIPT_FILE_PATH', '')  # optionally specify in an environment variable, otherwise defaults
if not CLEANUP_SCRIPT_FILE_PATH:
    CLEANUP_SCRIPT_FILE_PATH = os.path.abspath(os.path.expanduser(os.path.join(os.environ['WORKSPACE'], os.environ.get('CLEANUP_SCRIPT_NAME', 'dawn_delete_old_published_moduleload.sh'))))

def generate_cleanup_script():
    # generate the shell commands required to delete old backups

    products_deleted = 0
    products_kept = 0
    error_count = 0
    config = ConfigParser.SafeConfigParser()

    with open(CLEANUP_SCRIPT_FILE_PATH, 'w') as script_file:
        script_file.write('### File generated ' + time.strftime("%a, %Y/%m/%d %H:%M:%S UTC%z") +
                          ' (Jenkins ' + os.environ.get('BUILD_TAG','$BUILD_TAG:missing') + ' ' + os.environ.get('BUILD_URL','$BUILD_URL:missing') + ')\n\n')
        script_file.write('cleanup_script ()  {\n')

        for parent_dir in PUBLISH_DIRECTORY_PARENTS:
            if (not os.path.isdir(parent_dir)) or os.path.islink(parent_dir):
                print('*** Error: directory %s not found' % (parent_dir,))
                error_count += 1
                continue
            for root, dirs, files in os.walk(parent_dir):
                if 'plugins' in dirs:
                    dirs[:] = []  # we are in a directory that is a single published product, so ignore this directory, and do not recurse into it
                    continue
                if not 'cleanup.config' in files:
                    continue
    
                dirs[:] = []  # directories with a cleanup.config for processing (or ignoring) are never nested, so no need to look beneath this directory
                config.readfp(open(os.path.join(root, 'cleanup.config')))
                if not config.getboolean('DEFAULT', 'process_this_directory'):
                    continue  # ignore this directory, and do not recurse into it

                # root is a directory that can be cleaned up. find out what symbolic links point to
                targets_of_symbolic_links = {}  # key is target, value is a list of symlinks that point to it (probably just 1)
                for possible_symlink in sorted(os.listdir(root), reverse=True):
                    possible_symlink_path = os.path.join(root, possible_symlink)
                    possible_symlink_stat = os.lstat(possible_symlink_path)
                    if stat.S_ISLNK(possible_symlink_stat.st_mode):
                        targets_of_symbolic_links.setdefault(os.readlink(possible_symlink_path), []).append(possible_symlink)
    
                # for each product directory, there is a minimum number of versions to keep
                try:
                    minimum_number_of_versions_per_platform_to_keep = config.getint('DEFAULT', 'minimum_number_of_versions_per_platform_to_keep')
                    keep_all_versions_newer_than_days = config.getint('DEFAULT', 'keep_all_versions_newer_than_days')
                except ValueError as e:
                    print('*** Error: directory %s has invalid cleanup.config: %s' % (root, e))
                    error_count += 1
                    continue  # skip this directory, and continue
                if not (minimum_number_of_versions_per_platform_to_keep > 0 and keep_all_versions_newer_than_days > 0):
                    print('*** Error: directory %s has invalid cleanup.config: minimum number and days to keep must be non-zero' % (root,))
                    error_count += 1
                    continue  # skip this directory, and continue
    
                today_date = datetime.date.today()
                for platform in ('linux32', 'linux64', 'mac32', 'mac64', 'windows32', 'windows64'):  # note that mac32 exists in old releases
                    products_kept_for_platform = 0
                    for productdir in sorted((dir for dir in os.listdir(root) if dir.endswith(platform)), reverse=True):
                        productdir_path = os.path.join(root, productdir)
                        productdir_stat = os.lstat(productdir_path)
                        if not stat.S_ISDIR(productdir_stat.st_mode):
                            continue
                        if (productdir in targets_of_symbolic_links):
                            if len(targets_of_symbolic_links[productdir]) == 1:
                                reason_to_keep = '(target of symlink %s)' % targets_of_symbolic_links[productdir][0]
                            else:
                                reason_to_keep = '(target of symlinks %s)' % map(str, targets_of_symbolic_links[productdir])
                        elif products_kept_for_platform < minimum_number_of_versions_per_platform_to_keep:
                            reason_to_keep = '(keep at least %s versions per platform)' % minimum_number_of_versions_per_platform_to_keep
                        elif (today_date - datetime.date.fromtimestamp(productdir_stat.st_mtime)).days < keep_all_versions_newer_than_days:
                            reason_to_keep = '(keep versions newer than %s days)' % keep_all_versions_newer_than_days
                        else:
                            reason_to_keep = None
                        if reason_to_keep:
                            print('  : keeping      %-95s %s' % (productdir_path, reason_to_keep))
                            products_kept_for_platform += 1
                            products_kept += 1
                        else:
                            print('  : will delete  %s' % (productdir_path,))
                            script_file.write('  chmod -R u+w %s\n' % productdir_path)
                            script_file.write('  rm -rf       %s\n' % productdir_path)
                            products_deleted += 1
        script_file.write('\n  echo "set-build-description: ')
        if error_count:
            script_file.write('ERRORS: %s; ' % (error_count,))
        script_file.write('%s directories deleted, %s kept"\n' % (products_deleted, products_kept,))
        script_file.write('}\n\ncleanup_script\n')

###############################################################################
# Command line processing                                                     #
###############################################################################

if __name__ == '__main__':
    generate_cleanup_script()

