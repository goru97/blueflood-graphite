#!/bin/bash -x
BLUEFLOOD_URL=${1:-"http://localhost:20000"}
TENANT_ID=$2
exec 2>&1
exec 1>/tmp/bash-debug.log
apt-get update -y --force-yes
echo installing packages now, one at a time.
for i in wget oracle-java7-installer git python-dev python-setuptools python-pip build-essential libcairo2-dev libffi-dev python-virtualenv python-dateutil ; do
  echo installing "$i"
  apt-get install -y $i --force-yes 2>&1 | tee /tmp/$i.install.log
done
pip install gunicorn
pip install --upgrade "git+http://github.com/rackerlabs/graphite-api.git@george/fetch_multi_with_patches"
git -C /tmp clone https://github.com/rackerlabs/blueflood.git
git -C /tmp/blueflood checkout master
cd /tmp/blueflood/contrib/graphite
python setup.py install
cat > /etc/graphite-api.yaml << EOL
search_index: /dev/null
finders:
  - blueflood.TenantBluefloodFinder
functions:
  - graphite_api.functions.SeriesFunctions
  - graphite_api.functions.PieFunctions
time_zone: UTC
blueflood:
  tenant: TENANT_ID
  urls:
    - BLUEFLOOD_URL
EOL
cat > /etc/init/graphite-api.conf << EOL
description "Graphite-API server"
start on runlevel [2345]
stop on runlevel [!2345]
console log
respawn
exec gunicorn -b 127.0.0.1:8888 -w 8 graphite_api.app:app
EOL
start graphite-api