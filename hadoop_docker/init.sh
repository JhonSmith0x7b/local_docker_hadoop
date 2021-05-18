#! /bin/bash

service ssh restart
#hdfs namenode -format -y
echo "Done! Good Luck."
tail -f /dev/null
