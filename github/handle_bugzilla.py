#!/usr/bin/python
"""
Handle bugzilla updates via Jenkins
"""
from __future__ import unicode_literals, absolute_import, print_function
import argparse
import os
import sys
import bugzilla
import commit


BUG_STATUS = ("POST", "MODIFIED")
REVIEW_STATUS = ("Open", "Merged", "Abandoned")


def create_comment(template_id, change):
    """
    Create the comment from the template
    """
    comment_template = [
        "REVISION POSTED: {} ({}) posted (#{}) for review on {} by {}",
        "REVIEW: {} ({}) posted (#{}) for review on {} by {}",
        "REVIEW: {} ({}) merged (#{}) on {} by {}",
    ]
    return comment_template[template_id].format(
        change["url"],
        change["sub"],
        change["revision_number"],
        change["branch"],
        change["uploader_name"],
        )



class Bug(object):
    def __init__(self, bug_id=None, bug_status=None, product=None, dry_run=True):
        self.bug_id = bug_id
        self.product = product
        self.bug_status = bug_status
        # There should always be a bug and product
        assert self.bug_id is not None
        assert self.bug_status is not None
        assert self.product is not None
        bz_url = "https://bugzilla.redhat.com"
        self.bz = bugzilla.Bugzilla(bz_url)
        self.old_bugs = None
        self.dry_run = dry_run

    def product_check(self):
        """
        Check that the bug is filed in the correct product
        """
        bug = self.bz.getbug(self.bug_id)
        if bug.product.lower() != self.product.lower():
            return False
        return True

    def needs_update(self, commit_obj, event):
        """
        The code to check if a bug needs update
        """
        # On a merge event or on the first revision, comment right away
        if event == "change-merged" or commit_obj.revision_number == 1:
            return True

        old_commit = commit_obj.get_commit_message_from_gerrit()
        old_bugs = commit_obj.parse_commit_message(old_commit)
        old_bugs = [x["id"] for x in old_bugs]

        # if there are no old bugs at all
        if not old_bugs:
            return True

        unified_bugs = list(set(set(old_bugs) | set([self.bug_id])))

        # If there is more than one unique issue between both sets, then a new
        # bug was added and an old one removed
        if len(unified_bugs) > 1:
            self.old_bugs = list(set(set(old_bugs) - set([self.bug_id])))
            return True

        # If there is only one unified issue between both commits and that is
        # equal to the current bug, do not comment
        elif len(unified_bugs) == 1 and unified_bugs[0] == self.bug_id:
            return False

        raise Exception(
            "Unexpected scenario occured. Please highlight this to the "
            "infra team"
        )

    def post_update(self, change):
        """
        Post an update to Bugzilla
        """
        # post an update to old bugs only
        if self.old_bugs:
            self.update_old_bug(change, create_comment(0, change))

        # update only current bug
        if change["event"] == "change-merged":
            comment = create_comment(2, change)
        else:
            comment = create_comment(1, change)

        # The bug status is changed to MODIFIED only when "Fixes" is in the
        # commit message associated with this bug, otherwise, it will be
        # "POST".
        bug_state = 0
        review_state = 0
        if "fixes" in self.bug_status.lower() and change["event"] == "change-merged":
            bug_state = 1
            review_state = 1

        self.create_update_ext_bug(
            change["number"], change["sub"], REVIEW_STATUS[review_state]
        )

        if self.dry_run:
            print(self.bug_id)
            print(comment)
            print(BUG_STATUS[bug_state])
            print(REVIEW_STATUS[review_state])
            return

        update = self.bz.build_update(comment=comment, status=BUG_STATUS[bug_state])
        self.bz.update_bugs(self.bug_id, update)

    def update_old_bug(self, change, comment):
        """
        Update the old bug only
        """
        for old in self.old_bugs:
            old_bug = self.bz.getbug(old)
            if old_bug.product.lower() == self.product.lower():
                # Look for old external tracker for this bug
                bug_obj = self.bz.getbug(old)
                remove_old_bug = False
                for ext_bug in bug_obj.external_bugs:
                    if (
                            ext_bug["ext_bz_id"] == 150
                            and ext_bug["ext_bz_bug_id"] == change["number"]
                    ):
                        remove_old_bug = True
                if self.dry_run:
                    print(old_bug)
                    print(comment)
                    print("Remove old external tracker: {}".format(remove_old_bug))
                else:
                    update = self.bz.build_update(comment=comment)
                    self.bz.update_bugs(old, update)
                    # Remove any old external bug tracker reference with
                    # this change
                    if remove_old_bug:
                        self.bz.remove_external_tracker(
                            ext_bz_bug_id=change["number"],
                            ext_type_id=150,
                            bug_ids=old,
                        )
            else:
                print(
                    "BUG {} not updated since it is not in "
                    "glusterfs product".format(old)
                )

    def create_update_ext_bug(self, change_number, change_sub, review_state):
        """
        check if there an external tracker already
        """
        create_ext_bug = True
        bug_obj = self.bz.getbug(self.bug_id)
        for ext_bug in bug_obj.external_bugs:
            if (
                    ext_bug["ext_bz_id"] == 150
                    and ext_bug["ext_bz_bug_id"] == change_number
            ):
                create_ext_bug = False

        if create_ext_bug:
            self.bz.add_external_tracker(
                ext_bz_bug_id=change_number,
                ext_type_id=150,
                ext_description=change_sub,
                bug_ids=self.bug_id,
                ext_status=review_state,
            )
            return
        self.bz.update_external_tracker(
            ext_bz_bug_id=change_number,
            ext_type_id=150,
            ext_description=change_sub,
            bug_ids=self.bug_id,
            ext_status=review_state,
        )

    def abandon(self, change):
        """
        Update bugzilla when a change in abandoned
        """
        self.create_update_ext_bug(change["number"], change["sub"], REVIEW_STATUS[2])
        # Update external bug status to "Abandoned"
        # Post an update stating the bug was closed.

    def restore(self, change):
        """
        Update bugzilla when a change is restored
        """
        # Update external bug status to "Open"
        self.create_update_ext_bug(change["number"], change["sub"], REVIEW_STATUS[0])
        # Post an update stating the bug was re-opened


def main(dry_run=True, abandon=False, restore=False):
    """
    Main function where everything comes together
    """
    if os.getenv("GERRIT_PROJECT") != "glusterfs":
        return False

    # Dict of change-related info
    change = {
        "url": os.getenv("GERRIT_CHANGE_URL"),
        "sub": os.getenv("GERRIT_CHANGE_SUBJECT"),
        "revision_number": os.getenv("GERRIT_PATCHSET_NUMBER"),
        "branch": os.getenv("GERRIT_BRANCH"),
        "uploader_name": os.getenv("GERRIT_PATCHSET_UPLOADER_NAME"),
        "event": os.getenv("GERRIT_EVENT_TYPE"),
        "number": os.getenv("GERRIT_CHANGE_NUMBER"),
    }

    # get commit message
    commit_obj = commit.CommitHandler(repo=None, issue=False)
    commit_msg = commit.get_commit_message()

    # get bugs from commit message
    bugs = commit_obj.parse_commit_message(commit_msg)

    # There should only be one bug. In the event, there's more than one, it's
    # a parse error. Raise the error rather than silently ignoring it
    if len(bugs) > 1:
        raise Exception("More than one bug found in the commit message {}".format(bugs))
    elif not bugs:
        print("No bugs found in the commit message")
        return True

    # Create a bug object from ID
    print("Creating bug object")
    bug = Bug(
        bug_id=bugs[0]["id"],
        bug_status=bugs[0]["status"],
        product="GlusterFS",
        dry_run=dry_run,
    )

    print("Product check")
    # Check that the product is correct
    if not bug.product_check():
        raise Exception("This bug is not filed in the {} product".format("GlusterFS"))

    if abandon:
        bug.abandon(change)
        return True
    if restore:
        bug.restore(change)
        return True
    # Check that the bug needs an update based on the event and the revision
    # number
    if not bug.needs_update(commit_obj, change["event"]):
        return True
    print("Posting update")
    bug.post_update(change)
    return True


if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(description="Comment on Bugzilla bug")
    PARSER.add_argument(
        "--dry-run",
        "-d",
        action="store_true",
        help="Do not comment on Bugzilla. Print to stdout instead",
    )
    PARSER.add_argument(
        "--abandon", action="store_true", help="This change is abandoned"
    )
    PARSER.add_argument(
        "--restore", action="store_true", help="This change is being restored"
    )
    ARGS = PARSER.parse_args()
    if not main(ARGS.dry_run, abandon=ARGS.abandon, restore=ARGS.restore):
        sys.exit(1)
