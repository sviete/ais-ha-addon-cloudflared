# AIS Cloudflared

View English description below | [Go to English description below](#english-description)

Cloudflared łączy Twoją instancję Home Assistant poprzez bezpieczny tunel
z wybraną przez Ciebie subdomeną na hoście `paczka.pro`. Dzięki temu możesz
bezpiecznie udostępnić instancję swojego Home Assistant-a w Internecie
bez otwierania portów na routerze. Twoja instancja Home Assistent będzie
dostępna pod adresem `<twoja-wybrana-subdomena>.paczka.pro`.

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-tunnel.png)

## Początkowe ustawienia

### Konfiguracja dodatku AIS Cloudflared

W poniższych krokach pokażemy jak utworzyć tunel AIS Cloudflare i udostępnić
swoją instancję Home Assistant w Internecie.

#### 1. Skonfiguruj integrację `http` w Home Assistant `configuration.yaml`

Ponieważ Home Assistant blokuje żądania od serwerów proxy/reverse proxy,
trzeba ustowić w swojej instancji, aby zezwoliła na żądania z dodatku
Cloudflared. Dodatek działa lokalnie, więc wystarczy, że HA będzie ufać
sieci doker. W tym celu należy dodać następujące linie do pliku `/usr/share/hassio/homeassistant/configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

**Notatka**: _Nie ma potrzeby dostosowywania niczego w tych liniach, ponieważ
sieci doker jest zawsze taka sama._

Pamiętaj o ponownym uruchomieniu Home Assistant po zmianie konfiguracji.

#### 2. Dodaj repozytorium dodatków AIS w Home Assistant

W sklepie z dodatkami Home Assistant dostępna jest możliwość dodania
repozytorium.Aby dodać to repozytorium, kliknij trzy kropki po prawej stronie
na górze strony, wybierz opcje `Repozytoria` i użyj następującego adresu URL:

```shel
https://github.com/sviete/ais-ha-addons
```

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-repo-add.png)

#### 3. Zainstaluj dodatek `AIS Cloudflared`

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-install.png)

#### 4. Skonfiguruj dodatek `AIS Cloudflared`

W konfiguracji podaj nazwę subdomeny pod którą chcesz żeby była dostępna Twoja
instancja Home Assistant. Dodatkowo podaj też hasło którym zarezerwujesz sobie
subdomene na własność - tylko osoba która zna to hasło może uruchomić tunel
z taką subdomeną.

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-config.png)

Zapisz swoją konfigurację.

#### 5. Uruchom dodatek `AIS Cloudflared` i obserwuj logi

Z logów dowiesz się czy subdomena którą wybrałeś była dostępna i czy tunel
został prawidłowo uruchomiony.

![ais tunnel](https://raw.githubusercontent.com/sviete/ais-ha-addon-cloudflared/main/docs/images/ais-logs.png)

## English description

### TODO

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
