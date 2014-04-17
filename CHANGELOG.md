2014-04-17  version 2.4.0
=========================
* Merged pull request https://github.com/adamsb6/s3_file/pull/25.  This provides new functionality to automatically decrypt an encrypted file uploaded to S3.

2014-03-18  version 2.3.3
=========================
* Merged pull request https://github.com/adamsb6/s3_file/pull/24.  This corrects documentation for use of X-Amz-Meta-Digest to identify md5 in multi-part uploads.

2014-02-20  version 2.3.2
=========================
* Added documentation for multi-part ETag/MD5 issue.
* Added changelog, backdated to 2014-02-14.

2014-02-14  version 2.3.1
=========================
* Merged pull request https://github.com/adamsb6/s3_file/pull/22.  This fixes an issue in which an :immediately arg to notify would trigger the notified resource before file permissions had been set.