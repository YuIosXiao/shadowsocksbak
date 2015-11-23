ChinaDNS-Python
===============

[![PyPI version]][PyPI] [![Build Status]][Travis CI]

Fix [weird things] with DNS in China.

[ChinaDNS-C] is more advanced and well maintained. Please use it instead.

Actually, I'm not working on the Python version anymore.
New maintainers are welcome. Just send several pull requests and let
me know. You can begin with some features that have already
been implemented in ChinaDNS-C.

Install
-------

* Linux / OS X

    * [ChinaDNS-C]

* Windows

    * [Download]

* OpenWRT

    * [ChinaDNS-C]

Usage
-----

Run `sudo chinadns` on your local machine. ChinaDNS creates a DNS server at
`127.0.0.1:53`.

Set your DNS to 127.0.0.1 and you're done.

    $ nslookup www.youtube.com
    Server:		127.0.0.1
    Address:	127.0.0.1#53
    
    Non-authoritative answer:
    www.youtube.com	canonical name = youtube-ui.l.google.com.
    youtube-ui.l.google.com	canonical name = youtube-ui-china.l.google.com.
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.102
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.101
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.113
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.100
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.139
    Name:	youtube-ui-china.l.google.com
    Address: 173.194.72.138

Advanced
--------

    usage: chinadns [-h] [-b BIND_ADDR] [-p BIND_PORT] [-s DNS]

    Forward DNS requests.

    optional arguments:
      -h, --help            show this help message and exit
      -b BIND_ADDR, --local_address BIND_ADDR
                            address that listens, default: 127.0.0.1
      -p BIND_PORT, --local_port BIND_PORT
                            port that listens, default: 53
      -s DNS, --dns DNS     DNS server to use, default:
                            114.114.114.114,208.67.222.222,8.8.8.8

License
-------
MIT

Bugs and Issues
----------------
Please visit [Issue Tracker]

Mailing list: http://groups.google.com/group/shadowsocks


[bad IPs]:         https://github.com/clowwindy/ChinaDNS-Python/blob/master/iplist.txt
[Build Status]:    https://img.shields.io/travis/clowwindy/ChinaDNS-Python/master.svg?style=flat
[ChinaDNS-C]:      https://github.com/clowwindy/ChinaDNS
[Download]:        https://sourceforge.net/projects/chinadns/files/dist/
[Fake IP]:              https://github.com/clowwindy/ChinaDNS/issues/42
[Issue Tracker]:   https://github.com/clowwindy/ChinaDNS-Python/issues?state=open
[PyPI]:            https://pypi.python.org/pypi/chinadns
[PyPI version]:    https://img.shields.io/pypi/v/chinadns.svg?style=flat
[Shadowsocks]:     https://github.com/clowwindy/shadowsocks
[Travis CI]:       https://travis-ci.org/clowwindy/ChinaDNS-Python
[weird things]:    http://en.wikipedia.org/wiki/Great_Firewall_of_China#Blocking_methods
