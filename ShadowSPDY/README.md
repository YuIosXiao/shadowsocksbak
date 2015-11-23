ShadowSPDY
==========
[![Build Status][1]][2]

ShadowSPDY is a tunnel proxy, which builds on top of [Shadowsocks][3] and 
[SPDY][4].

**Experiments show that ShadowSPDY is less efficient than Shadowsocks
with [TCP Fast Open][7] support.**

Usage
-----

ShadowSPDY is currently beta. Future versions may NOT be compatible with this 
version.

This project is experimental and in its very early stage. **DO NOT DEPLOY IT 
FOR PRODUCTION USAGE!**

You can submit bugs and issues on the [issue tracker][5].

For those who are willing to help developing or testing, here's the manual.

    # install node.js v0.10 from http://nodejs.org/ first
    git clone https://github.com/clowwindy/ShadowSPDY.git
    cd ShadowSPDY/
    npm install
    vim config.json
    bin/splocal  # or bin/spserver
    # then point your browser proxy into "socks5 127.0.0.1:1081"

Protocol
--------

ShadowSPDY simply adds an SPDY layer into Shadowsocks. Thus it provides benefits 
from SPDY, such as low latency, low resource consumption. On the other hands, 
all disadvantages, such as one single packet loss will slow down all active
streams.

ShadowSPDY works best on VPS with > 200ms RTT, < 2% packet loss, according to
[Google's research on SPDY][6]. Notice that when packet loss is high
(e.g. >10%), ShadowSPDY will be significantly slower than Shadowsocks.

### Shadowsocks

    |-------------------------|
    |          Socks5         |
    |-------------------------|
    |    Shadow Encryption    |
    |-------------------------|

### ShadowSPDY

    |-------------------------|
    |         Socks5          |
    |-------------------------|
    |          SPDY           |
    |-------------------------|
    |    Shadow Encryption    |
    |-------------------------|

License
-------

ShadowSPDY

Copyright (c) 2014 clowwindy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


[1]: https://travis-ci.org/clowwindy/ShadowSPDY.svg?branch=master
[2]: https://travis-ci.org/clowwindy/ShadowSPDY
[3]: https://github.com/clowwindy/shadowsocks
[4]: http://www.chromium.org/spdy
[5]: https://github.com/clowwindy/ShadowSPDY/issues
[6]: http://www.chromium.org/spdy/spdy-whitepaper#TOC-Preliminary-results
[7]: https://github.com/clowwindy/shadowsocks/wiki/TCP-Fast-Open
