#!/bin/bash
while true; do
    mysql -u root -h127.0.0.1 -P4000 -e "insert into ccm.ccm_t1 values (1,'111')"
done
