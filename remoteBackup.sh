#!/bin/bash

################################################################################
# Script to mv archives offsite
################################################################################

sftpUser='richardvdijk@richardvdijk.stackstorage.com'
sftpServer='richardvdijk.stackstorage.com'


sftp -R 256 -B 131072 -C richardvdijk@richardvdijk.stackstorage.com@richardvdijk.stackstorage.com <<< $'put -r backups/archives/'
