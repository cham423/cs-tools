## Overview 
This is my modified copy of the https-c2-done-right.sh script, to work with certbot properly on Ubuntu and Debian

## OS Support
Currently the script has been tested on:
- Ubuntu 18.04
- Ubuntu 20.04
- Debian 10

## Usage
1. update/upgrade OS to most recent
1. copy cobaltstrike tgz, and extract
1. create a DNS record that points to your domain i.e. c2.hack.dev
	- this is only going to be used for the https certificate. if you use a CDN, this will never be disclosed
1. run `bash https-c2.sh`
1. run `cloundfront_opsec.sh`, optionally, to block traffic from everywhere other than cloudfront on web ports

## Todo:
- add options to run individual functions instead of whole script
- add config file
- add cert renewal for long-running c2
- add profile generation
- fix all those pesky single quotes
- learn bash
