#!/usr/bin/python

from __future__ import unicode_literals
import base64
import os
import re
import bugzilla
import commit


class Bug(object):
    def __init__(self, id=None, product=None):
        self.id = id
        self.product = product
        # There should always be a bug and product
        assert self.id is not None
        assert self.product is not None
        bz_url = 'https://bugzilla.redhat.com'
        self.bz = bugzilla.Bugzilla(bz_url)
        self.old_bugs = None

    def product_check(self):
        '''
        Check that the bug is filed in the correct product
        '''
        bug = self.bz.getbug(self.id)
        if bug.product.lower() != self.product.lower():
            return False
        return True

    def needs_update(self, commit_obj, event):
        # On a merge event or on the first revision, comment right away
        if event == 'change-merged' or commit_obj.revision_number == 1:
            return True

        old_commit = commit_obj.get_commit_message_from_gerrit()
        old_bugs = commit_obj.parse_commit_message(old_commit)

        # if there are no old bugs at all
        if not old_bugs:
            return True

        unified_bugs = list(set(set(old_bugs) | set([self.id])))

        # If there is more than one unique issue between both sets, then a new
        # bug was added and an old one removed
        if len(unified_bugs) > 1:
            self.old_bugs = list(set(set(old_bugs) - set([self.id])))
            return True

        # If there is only one unified issue between both commits and that is
        # equal to the current bug, do not comment
        elif len(unified_bugs) == 1 and unified_bugs[0] == self.id:
            return False

        raise Exception('Unexpected scenario occured. Please highlight this '
                        'to the infra team')

    def post_update(self):
        # post an update to old bugs only
        if self.old_bugs:
            for old in old_bugs:
                comment = "REVISION POSTED: {} ({}) posted (#{}) for review on {} by {}"
                old_bug = bz.getbug(old)
                if old_bug.product.lower() == self.product.lower():
                    old_bug.build_update(
                            comment=comment)
                else:
                    print("BUG {} not updated since it is not in "
                          "glusterfs product".format(old))
        "REVIEW: {} ({}) posted (#{}) for review on {} by {}"
        # update only current bug


def main():
    # check if the project is glusterfs
    if os.getenv('GERRIT_PROJECT') != 'glusterfs':
        return False

    # get commit message
    commit_obj = commit.CommitHandler(repo)
    commit_msg = commit.get_commit_message()

    # get bugs from commit message
    bugs = commit_obj.parse_commit_message(commit_msg)

    # There should only be one bug. In the event, there's more than one, it's
    # a parse error. Raise the error rather than silently ignoring it
    if len(bugs) != 1:
        raise('More than one bug found in the commit message {}'.format(bugs))

    # Create a bug object from ID
    bug = Bug(id=bugs[0], product='GlusterFS')

    # Check that the product is correct
    if not bug.product_check('GlusterFS'):
        return True

    # Check that the bug needs an update based on the event and the revision
    # number
    if not bug.needs_update(commit_obj,
            os.getenv('GERRIT_EVENT_TYPE')):
        return True
    bug.post_update(
            change_url=os.getenv('GERRIT_CHANGE_URL'),
            change_sub=os.getenv('GERRIT_CHANGE_SUBJECT'),
            revision_number=os.getenv('GERRIT_PATCHSET_NUMBER'),
            branch=os.getenv('GERRIT_BRANCH'),
            uploader_name=os.getenv('GERRIT_PATCHSET_UPLOADER_NAME'),
            )
    return True


if __name__ == '__main__':
    if not main():
        sys.exit(1)
