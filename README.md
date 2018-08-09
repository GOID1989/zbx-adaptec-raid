# zbx-adaptec-raid
Zabbix Template and PowerShell\BASH script with Low Level Discovery (LLD) for Adaptec RAID Controllers.
Work on Windows and Linux.

![alt_text](https://github.com/GOID1989/zbx-adaptec-raid/blob/master/adaptec-raid.png)

## Prerequisites:
 - Adaptec Storage Manager CLI Tools
 - Add UserParameter to zabbix-agent config

**ToDO:**
 - [X] Temperature monitoring
 - [X] Battery status check
 
**Tested on:**
 - Adaptec 6805
 - Adaptec 6405
 - Adaptec 2405
 - Adaptec 5405
 - Windows 2008r2
 - Windows 2012r2
 - Debian 6

## Notice
 - Script written with LLD-support for Multi-controller env - BUT not tested! Please notify me if check this in those conf.
 - On Linux machine Battery LLD not tested
