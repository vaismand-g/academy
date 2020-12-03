#!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo echo "Hello World from $(hostname -f)" > /var/www/html/index.html