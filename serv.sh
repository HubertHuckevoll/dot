#!/bin/bash
#sudo busybox httpd -p 8080 -f -v -h ~/meyerk.published
cd "$1".published
php -S localhost:8080
