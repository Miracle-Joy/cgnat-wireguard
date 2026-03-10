#!/bin/bash

# 1. Esperar a que Docker levante completamente
sleep 10

# 2. Obtener la IP del contenedor de WireGuard dinámicamente 
WG_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wireguard)

if [ -z "$WG_IP" ]; then
    echo "Error: No se encontró el contenedor 'wireguard'. Asegúrate de que el nombre sea correcto."
    exit 1
fi

# 3. Limpiar rutas previas para evitar conflictos [cite: 15]
sudo ip route del 10.69.69.0/24 2>/dev/null
sudo ip route del 192.168.50.0/24 2>/dev/null

# 4. Configurar las rutas en el Host de la VPS hacia el contenedor [cite: 8, 15]
# Esto permite que Nginx Proxy Manager encuentre a n8n
sudo ip route add 10.69.69.0/24 via $WG_IP
sudo ip route add 192.168.50.0/24 via $WG_IP

# 5. Configurar el Forwarding y NAT dentro del contenedor 
# Esto convierte al contenedor en un "router" hacia tu casa
docker exec wireguard sysctl -w net.ipv4.ip_forward=1
docker exec wireguard iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT
docker exec wireguard iptables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
docker exec wireguard iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

echo "Configuración completada con éxito sobre IP: $WG_IP"