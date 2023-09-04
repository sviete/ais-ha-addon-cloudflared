# AIS Cloudflared

Cloudflared connects your Home Assistant Instance via a secure tunnel via Cloudflare
to a subdomain at `paczka.pro` host. This allows you to expose your Home
Assistant instance to the Internet without opening ports on your router.

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-tunnel.png)

## Local tunnel add-on setup

### 1. Configure the http integration in your Home Assistant config

Since Home Assistant blocks requests from proxies/reverse proxies, you need to tell
your instance to allow requests from the Cloudflared add-on. The add-on runs
locally, so HA has to trust the docker network. In order to do so, add the
following lines to your `/config/configuration.yaml`:

> Note: There is no need to adapt anything in these lines below,
> since the IP range of the docker network is always the same.

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

#### 2. Set subdomain and password

In the configuration, enter the name of the subdomain under which you want yours
Home Assistant instance to be available. In addition, enter the password that
you will reserve for yourself own subdomain - only the person who knows this
password can run the tunnel with this subdomain.

Save your configuration.

#### 3. Start the `AIS Cloudflared` add-on and watch the logs

From the logs you will find out if the subdomain you selected was available and whether
the tunnel has been started correctly.

#### 4. Access your Home Assistant via the remote URL without port

e.g.:

```yaml
https://my-ha.paczka.pro/
```

---

## License

MIT License

Copyright (c) 2023 AIS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
