import ast
import sys


def test_source_code_compatible(code_file):
    try:
        return ast.parse(code_file.read())
    except SyntaxError:
        return False


if __name__ == '__main__':
    for code in sys.argv:
        with open(code) as f:
            if not test_source_code_compatible(f):
                print("{} is not compatible".format(code))
