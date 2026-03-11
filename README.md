# 🚀 Salto de CGNAT con WireGuard y Nginx Proxy Manager

Esta guía detalla los pasos técnicos para configurar un VPS como túnel seguro, permitiendo el acceso a una red local que se encuentra detrás de un CGNAT. Esto permite exponer servicios locales al internet de forma segura.

### 📑 Tabla de Contenidos

* [1. Instalación de Docker y Herramientas](#1-instalación-de-docker-y-herramientas)
- Clonación de Repositorio
- Instalación de WireGuard
- Ruta Estática Persistente (Systemd)

### 1. Instalación de Docker y Herramientas

Prepara el sistema actualizando los paquetes e instalando el motor de Docker y las utilidades necesarias.
```bash
# Actualizar e instalar dependencias
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git netcat-openbsd

# Instalar Docker
curl -fsSL [https://get.docker.com](https://get.docker.com) | sh
sudo usermod -aG docker $USER

# Instalar Docker Compose v2
sudo curl -L "[https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname](https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname) -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```
## 2. Clonación de Repositorio

Obtén los scripts y archivos de configuración necesarios directamente en tu servidor.
```bash
git clone https://github.com/Miracle-Joy/cgnat-wireguard.git
cd cgnat-wireguard/vps
```
## 3. Instalación de WireGuard

### 3.1 Preparación y Firewall

Configura los permisos de los scripts y abre el puerto UDP necesario para la VPN.
```bash
sudo chmod +x setup-wireguard-tunnel.sh
sudo chmod +x fix-vpn-routing.sh
sudo ufw allow 51820/udp
sudo ufw enable
```
### 3.2 Crear Entorno de Archivos
Genera la estructura de carpetas requerida ejecutando el script de preparación:
```bash
sudo ./setup-wireguard-tunnel.sh
```
### 3.3 LEVANTAR EL CONTENEDOR ⚠️

> [!IMPORTANT]
**Este paso es crítico. Sin este comando, los pasos siguientes fallarán porque el contenedor no existirá en el motor de Docker.**
```bash
docker-compose up -d
```
### 3.4 Generar Claves (Con el contenedor activo)
Crea las llaves criptográficas necesarias para establecer el túnel.
```bash
mkdir -p config && cd config

#Generar claves del servidor
sudo docker exec wireguard wg genkey | sudo tee privatekey
sudo docker exec -i wireguard wg pubkey < privatekey | sudo tee publickey

#Generar clave para el cliente (Router Asus/Dispositivo local)
#Generar la clave privada
wg genkey 

#Generar la clave pública a partir de la privada (sustituye TU_CLAVE_PRIVADA)
echo "TU_CLAVE_PRIVADA" | wg pubkey
```

### 3.5 Configuración de Peers y Reinicio

Edita la configuración para enlazar tu dispositivo local al servidor:
```bash
nano config/wg_confs/wg0.conf
```
> [!IMPORTANT]
*Acción: Reemplaza el PublicKey de Peer1 por la clave pública generada para tu router.*                              
*Red Local: Asegúrate de que el Peer tenga AllowedIPs = 10.69.69.2/32, 192.168.50.0/24 (o el rango de tu red local).*

Reiniciar para aplicar cambios:
```bash
docker-compose restart wireguard
```

## 4. Ruta Estática Persistente (Systemd)

Configura un servicio de sistema para asegurar que las rutas de red se mantengan activas tras reiniciar el VPS.
```bash
sudo nano /etc/systemd/system/route-50.service
```
Pega el siguiente contenido en el archivo:
```bash
[Unit]
Description=Configuracion de Rutas y NAT para WireGuard
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash /root/cgnat-wireguard/vps/fix-vpn-routing.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```
Activar el servicio y reiniciar el servidor:
```bash
#recargar todos los archivos de configuración

sudo systemctl daemon-reload && sudo systemctl enable --now route-50.service

# Reinicia el servidor

sudo reboot
```

### 🛠️ Notas de Mantenimiento

A continuación se detallan los puntos clave para asegurar el funcionamiento del túnel:
```
[x]Verificar que el archivo fix-vpn-routing.sh tenga permisos de ejecución (chmod +x).
[x]Comprobar que el puerto 51820/udp esté abierto en el panel de control de tu proveedor de VPS.
```

## 📋 Direcciones de Red

| Recurso | Dirección IP | Descripción |
| :--- | :--- | :--- |
| Gateway VPN | 10.69.69.1 | IP del VPS dentro del túnel. |
| Cliente Local | 10.69.69.2 | IP reservada para el router o dispositivo local. |
| Rango Local | 192.168.50.0/24 | Red detrás del CGNAT (ejemplo). |

>[!TIP]
Si el túnel no levanta, revisa los logs del contenedor con docker logs wireguard.
