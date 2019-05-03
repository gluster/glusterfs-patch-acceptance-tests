#!/usr/bin/env python
'''
This code will handle the backporting command on Gerrit
'''
import sys
import os
import argparse
import requests
import commit
from handle_bugzilla import Bug

def clone_bug(bug_obj, component=None, version=None):
    #bz_url = 'https://bugzilla.redhat.com'
    #bz = bugzilla.Bugzilla(bz_url)
    bugid = bug_obj.bug_id
    old_bug = bug_obj.bz.getbug(bugid)
    cc = old_bug.cc
    cc.append(str(old_bug.reporter))
    depends_on = str(old_bug.bug_id) + ' '
    depends_on += ' '.join([str(i) for i in old_bug.dependson])
    # assign old bug's product
    new_product = bug_obj.product
    new_component = component
    if new_component is None:
        # assign old bug's component
        new_component = old_bug.component
    new_version = version
    if new_version is None:
        new_version = old_bug.version

    createinfo = bug_obj.bz.build_createbug(
        product=new_product,
        component=new_component,
        version=new_version,
        summary=old_bug.summary,
        description=old_bug.description,
        depends_on=depends_on,
        blocks=old_bug.blocked,
        cc=cc,
        cf_clone_of=str(old_bug.id)
        )

    new_bug = bug_obj.bz.createbug(createinfo)
    print("Created clone bug id=%s url=%s" % (new_bug.id, new_bug.weburl))
    # Update Blocks, Clones, comment section on the bug
    update = bug_obj.bz.build_update(blocks=new_bug.id, clones=new_bug.id,
                                     comment=("Blocks: {}".format(new_bug.id)))
    bug_obj.bz.update_bugs(old_bug.id, update)
    return new_bug


def gerrit_update(bugid, version, change_id, main_branch, project,
                  patchset_number, commit_message, username, password):
    # cherrypick to the specified version
    # should return with gerrit URL to new commit
    url = ('https://review.gluster.org/a/changes/{}~{}~{}/revisions/{}'
           '/cherrypick'.format(project, main_branch, change_id, patchset_number))
    data = {
        'message' : commit_message,
        'destination' : version
        }
    response = requests.post(url, auth=(username, password), json=data)
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError:
        print(response.text)
        sys.exit(1)

    # update the topic on gerrit
    url = ('https://review.gluster.org/a/changes/{}~{}~{}'
           '/topic'.format(project, version, change_id))
    data = {
        'topic' : 'ref-{}'.format(bugid)
        }
    response = requests.put(url, auth=(username, password), json=data)
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError:
        print(response.text)
        sys.exit(1)


def main():
    '''
    Main function where function call and variables are initiated
    '''
    # check if the project is GlusterFS
    if os.getenv('GERRIT_PROJECT') != 'glusterfs':
        return False

    #get commit message
    commit_obj = commit.CommitHandler(repo=None, issue=False)
    commit_msg = commit.get_commit_message()

    # get bugs from commit message
    bugs = commit_obj.parse_commit_message(commit_msg)

    # There should only be one bug. In the event, there's more than one, it's
    # a parse error. Raise the error rather than silently ignoring it
    if len(bugs) > 1:
        raise Exception('More than one bug found in the commit message {}'.format(bugs))
    elif not bugs:
        print("No bug found in the commit message. Mention the bug that needs \
              to be backported in the specific release branch")
        return False

    # Create a bug object from ID
    bug = Bug(bug_id=bugs[0]['id'], bug_status=bugs[0]['status'], product='GlusterFS')

    # Check that the product is correct
    if not bug.product_check():
        raise Exception('This bug is not filed in the {} product'.format('GlusterFS'))

    # get all the values from Jenkins environment variables
    change_id = os.environ.get('GERRIT_CHANGE_ID')
    branch = os.environ.get('GERRIT_BRANCH')
    project = os.environ.get('GERRIT_PROJECT')
    patchset_number = os.environ.get('GERRIT_PATCHSET_NUMBER')
    bz_username = os.environ.get('HTTP_USERNAME')
    bz_password = os.environ.get('HTTP_PASSWORD')
    # todo: Get proper commit message with new bug id
    message = os.environ.get('GERRIT_CHANGE_COMMIT_MESSAGE')
    commit_message = '{}\n\nChange-Id: {}'.format(message, change_id)
    comment_added = os.environ.get('GERRIT_CHANGE_COMMENT_TEXT')
    version = comment_added.split(' ')[1]
    component = comment_added.split(' ')[2]

    cloned_bug = clone_bug(bug, component=component, version=version)
    gerrit_update(cloned_bug.id, version, change_id, branch, project,
                  patchset_number, commit_message, bz_username, bz_password)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='backport commit to a specific branch')
    #parser.add_argument('--version', '-v', help='where to backport the commit')
    #parser.add_argument('--component', help='component of the product')
    parser.add_argument('--product', help='name of the product', default='GlusterFS')
    args = parser.parse_args()
    version = args.version
    component = args.component
    product = args.product
    if not main():
        sys.exit(1)
    else:
        print('Backporting is done')
