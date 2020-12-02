#!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
sudo sed -i '/Listen/{s/\([0-9]\+\)/8080/; :a;n; ba}' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo echo "Hello World from $(hostname -f)" > /var/www/html/index.html