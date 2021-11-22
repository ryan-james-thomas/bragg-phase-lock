#!/bin/bash

cp phase-lock/phase-lock.runs/impl_1/system_wrapper.bit phase-lock.bit
sshpass -proot scp phase-lock.bit root@rp-ffffc2.local:/root/phase-lock/


