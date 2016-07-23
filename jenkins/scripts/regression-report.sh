#!/bin/bash

#Usage: regression-report.sh <last number of days>
# if anything fails, we'll abort
set -e
yum install -y python-dateutil python-blessings python-requests python-lxml

no_of_days=$1
git clone https://github.com/gluster/glusterfs.git
cd glusterfs/
python extras/failed-tests.py --html_report get-summary $no_of_days centos netbsd > regression_report.html
(
echo "To: gluster-devel@gluster.org";
echo "Subject: Regression report";
echo "Content-Type: html";
echo "MIME-Version: 1.0";
echo "";
cat regression_report.html;
) | sendmail -t
