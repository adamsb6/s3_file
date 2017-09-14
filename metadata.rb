name             "s3_file"
maintainer       "Brandon Adams"
maintainer_email "brandon.adams@me.com"
license          "MIT"
description      "Installs/Configures s3_file LWRP"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "2.8.5"

source_url 'https://github.com/adamsb6/s3_file' if responds_to(:source_url)
issues_url 'https://github.com/adamsb6/s3_file/issues' if responds_to(:issues_url)

chef_version '>= 12.6' if responds_to(:chef_version)

supports 'centos'
supports 'redhat'
supports 'windows'
