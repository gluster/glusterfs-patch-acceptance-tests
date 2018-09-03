import ast
import sys
from platform import python_version


def test_source_code_compatible(code_file):
    try:
        return ast.parse(code_file.read())
    except SyntaxError:
        return False


def test_files(files):
    success = True
    for code in files:
        with open(code) as f:
            if not test_source_code_compatible(f):
                success = False
                print("{} is not compatible with Python {}".format(
                    code,
                    python_version())
                )
    return success

if __name__ == '__main__':
    success = test_files(sys.argv)
    if not success:
        sys.exit(1)
