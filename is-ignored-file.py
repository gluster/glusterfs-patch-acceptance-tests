#!/usr/bin/env python
import argparse
import os.path
from fnmatch import fnmatch
import sys


def pattern_test(path, pattern):
    if fnmatch(path, pattern.strip()):
        sys.exit(0)


parser = argparse.ArgumentParser(description='Check if the file is ignored')
parser.add_argument('path', metavar='PATH', type=unicode,
                    help='The path to the file to test')
parser.add_argument('--ignore-file', default='.testignore',
                    metavar='IGNORE_FILE',
                    help='Path to the .testignore file')

args = parser.parse_args()
if not os.path.isfile(args.ignore_file):
    # This means we're working on an older branch without the .testignore file
    patterns = ['doc/*', 'build-aux/*']
    for pattern in patterns:
        pattern_test(args.path, pattern.strip())
else:
    with open(args.ignore_file) as f:
        for pattern in f:
            pattern_test(args.path, pattern.strip())
sys.exit(1)
