#!/bin/bash

ip address show eth0 | grep 'dynamic' | awk '{print $2}' | cut -f1 -d'/'
