#!/bin/bash
#
# 1. download the build log
# 2. check if the regex(es) are found in the build log
#

# if anything fails, we'll abort
set -e

curl -o build.log ${BUILD_LOG}

# Formats to complain about:
#
# 1. XXX: warning: format '%XXX' expects argument of type 'XXX', but argument XXX has type 'ssize_t {aka int}' [-Wformat=]
# 2. XXX: warning: format '%XXX' expects argument of type 'XXX', but argument XXX has type 'size_t {aka unsigned int}' [-Wformat=]
#
# Note: the "{aka unsigned int}" and "[-Wformat=]" are only seen in recent
#        compilers. Also " argument of" seems to be optional.

rm -f warnings.txt
grep -E ".*: warning: format '%.*' expects( argument of)? type '.*', but argument .* has type 'ssize_t" build.log | tee -a warnings.txt
grep -E ".+: warning: format '%.+' expects( argument of)? type '.+', but argument .+ has type 'size_t" build.log | tee -a warnings.txt

WARNINGS=$(wc -l < warnings.txt)
exit ${WARNINGS}
