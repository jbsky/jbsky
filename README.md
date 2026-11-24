### Bonjour 👋

Tombé dans l'informatique très jeune, j'en ai fait mon métier — et un homelab qui tourne comme une petite prod : routage, DNS, proxy, IPS, Kubernetes, supervision, domotique, tout en code et en CI.

J'écris ce que j'y apprends sur **[jbsky.fr](https://jbsky.fr)**.

---

#### 🛡️ Images de conteneurs durcies

Compilées depuis les sources, `FROM scratch` quand c'est possible : aucun shell, non-root, init Go statique, versions et sha256 dans un seul `versions.json`, scan de vulnérabilités à chaque build.

| Image | Rôle |
|---|---|
| [nginx-hardened](https://github.com/jbsky/nginx-hardened) | Nginx + ModSecurity v3 + OWASP CRS + GeoIP2 |
| [haproxy-hardened](https://github.com/jbsky/haproxy-hardened) | HAProxy en bordure |
| [traefik-hardened](https://github.com/jbsky/traefik-hardened) | Traefik, dashboard reconstruit depuis les sources |
| [bind9-hardened](https://github.com/jbsky/bind9-hardened) | BIND 9.20 |
| [squid-hardened](https://github.com/jbsky/squid-hardened) | Squid + C-ICAP + ClamAV |
| [suricata-hardened](https://github.com/jbsky/suricata-hardened) | Suricata 8 en IPS (NFQUEUE) |
| [varnish-hardened](https://github.com/jbsky/varnish-hardened) | Varnish Cache |
| [php-fpm-hardened](https://github.com/jbsky/php-fpm-hardened) | PHP-FPM optimisé WordPress |
| [uptime-kuma-hardened](https://github.com/jbsky/uptime-kuma-hardened) | Uptime Kuma (~190 Mo au lieu de 1,7 Go) |
| [radicale-hardened](https://github.com/jbsky/radicale-hardened) | CalDAV / CardDAV |

La CI commune vit dans **[hardened-ci](https://github.com/jbsky/hardened-ci)** : workflows réutilisables, reconstruction automatique sur CVE, correctifs npm automatiques, portes de contrôle communes aux dix dépôts.

#### ⚙️ Infra as code

- **[vyos-deploy](https://github.com/jbsky/vyos-deploy)** — playbooks Ansible qui déploient proxy filtrant et IPS en conteneurs sur un routeur VyOS
- **[k3s-deploy](https://github.com/jbsky/k3s-deploy)** — cluster K3s avec Traefik, CrowdSec et cert-manager
- **[helm-wordpress](https://github.com/jbsky/helm-wordpress)** — WordPress sur Kubernetes, uniquement avec des images durcies
- **[dashboard-victorialogs](https://github.com/jbsky/dashboard-victorialogs)** — 8 dashboards Grafana pour VictoriaLogs (GeoIP, geomap, filtres croisés)

#### 🏠 Domotique

- **[ha-glass-dashboard](https://github.com/jbsky/ha-glass-dashboard)** — thème Home Assistant glass-morphism, fond selon la météo, 33 templates button-card
- **[ha-psychrometrics](https://github.com/jbsky/ha-psychrometrics)** · **[psychrometric-card](https://github.com/jbsky/psychrometric-card)** — humidité absolue, point de rosée et enthalpie de chaque pièce, et le diagramme qui va avec
- **[moniwatt](https://github.com/jbsky/moniwatt)** — suivi électrique 4 voies : Pi Zero + Arduino Mega + ADS1115, MQTT vers Home Assistant
- **[homeassistant-blueprints](https://github.com/jbsky/homeassistant-blueprints)** — prise qui se rallume après coupure, ventilation proportionnelle

#### 🔧 Bas niveau

- **[mwlwifi](https://github.com/jbsky/mwlwifi)** — driver et rétro-ingénierie du firmware du Marvell 88W8864 (802.11ac)
- **[Debian-On-WRT1900AC-V1](https://github.com/jbsky/Debian-On-WRT1900AC-V1)** — Debian sur un routeur Linksys WRT1900AC

---

**Outils du quotidien** : Ansible · Terraform · Proxmox · VyOS · Kubernetes (K3s) · Podman / Docker · Gitea Actions · GitHub Actions · Python · Go · Bash · Home Assistant

📝 [jbsky.fr](https://jbsky.fr)
