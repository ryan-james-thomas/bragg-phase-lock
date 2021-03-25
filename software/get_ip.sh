#!/bin/bash

ip address show eth0 | grep '172.22' | awk '{print $2}' | cut -f1 -d'/'
