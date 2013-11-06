vagrant-osb
===========

Vagrant OSB Installation

You will need the following files to sucessfully install OSB.  You will need to download them from Oracle and accept their licensing agreement.

1) jdk-7u45-linux-x64.tar.gz
2) ofm_osb_generic_11.1.1.7_disk1_of_1.zip
3) p17071663_1036_Generic.zip (This is patchset 6 from Oracle for WebLogic 10..3.6) 
4) wls1036_generic.jar

Place these files in the root of the project:

<your path>/vagrant-osb/[your files go here]

You don't necessarily need the patch file, put it is easily obtained:

http://support.oracle.com and then login with your OTN Account.

If you do not download Patchset 6, then you will need to modify the site.pp in the manifests directory so that the Bsu is not run.It will fail...obviously without the file.


