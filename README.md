# 🚀 Salto de CGNAT con WireGuard y Nginx Proxy Manager

Esta guía detalla los pasos técnicos para configurar un VPS como túnel seguro, permitiendo el acceso a una red local que se encuentra detrás de un CGNAT. Esto permite exponer servicios locales al internet de forma segura.

## 🛠️ Requisitos
Antes de comenzar, asegúrate de contar con lo siguiente:
1. VPS: Una instancia virtual (ej. IONOS, la más sencilla es suficiente).
2. Router: Un router compatible con WireGuard (ej. ASUS RT-AX82U V2 con firmware Merlin).
3. Dominio: Un dominio propio (ej. Namecheap) con los DNS gestionados en Cloudflare.
4. Paciencia: El proceso requiere atención a los detalles técnicos.

### 📑 Tabla de Contenidos

* [1. Instalación de Docker y Herramientas](#1-instalación-de-docker-y-herramientas)
* [2. Clonación de Repositorio](#2-clonación-de-repositorio)
* [3. Instalación de WireGuard y Configuracion](#3-instalación-de-wireguard-y-configuracion)
* [4. Ruta Estática Persistente](#4-ruta-estática-persistente)
* [5. Instalacion de Nginx Proxy Manager](#5-instalacion-de-nginx-proxy-manager)
* [6. Importacion de archivo conf en Router](#6=importacion-de-archivo-conf-en-router)

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
### 2. Clonación de Repositorio

Obtén los scripts y archivos de configuración necesarios directamente en tu servidor.
```bash
git clone https://github.com/Miracle-Joy/cgnat-wireguard.git
cd cgnat-wireguard/vps
```
### 3. Instalación de WireGuard y Configuracion

### 3.1 Preparación y Firewall

Configura los permisos de los scripts y abre el puerto UDP necesario para la VPN.
```bash
sudo chmod +x setup-wireguard-tunnel.sh
sudo chmod +x fix-vpn-routing.sh
#No es necesario habilitar el firewall
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
### 3.6 Configuracion a Router
```bash
#Ingresa a la siguiente ruta y copialo
cat cgnat-wireguard/vps/config/peer1/peer1.conf
```
Esto lo pegan en archivo de texto y cambia la extension .txt a .conf el archivo nodebe llevar <> ni ""
```bash
#Ejemplo de como se ve:
[Interface]
Address = 10.69.69.2/24
PrivateKey = <Private Key Asus>
ListenPort = 51820
DNS = 10.69.69.1

[Peer]
PublicKey = "Este viene PublicKey no mover"
PresharedKey = "Este viene PresharedKey no mover" 
Endpoint = <ip de tu vps>:51820
AllowedIPs = 0.0.0.0/0, 192.168.50.0/24
```
### 3.7 Importar archivo al Router
Ingresa a tu router y ve al apartado VPN y selecciona Cliente VPN.
1. En Client control Preciona choose File y Cargar
2. En Network Habilitar NAT -> SI, Inbound Firewall => Allow, Killswitch -> No

<img width="754" height="481" alt="image" src="https://github.com/user-attachments/assets/9ae3c8d3-8fff-4094-8d27-3022f12470ac" />

### 3.8 Clientes dentro de la VPN
Ve al apartado VPN Director y baja a Add new rule y preciona el signo de + veras la siguiente imagen e ingresa los datos.

<img width="636" height="359" alt="image" src="https://github.com/user-attachments/assets/498f55fd-9d22-4af6-a008-39067ca5014a" />

Activa la VPN en WireGuard clients status que se encuentra en VPN Director asi debe verse.

<img width="757" height="529" alt="image" src="https://github.com/user-attachments/assets/1c13e5a8-928a-412c-a364-e8020d1e9b6c" />

### 3.9 En otros dispositivos
En este caso solo basta con copiar ve a cgnat-wireguard/vps/config y selecciona otro peer es uno por cada dispositivo en el docker-compose de wireguard nodifica el "PEERS=4" por el numero que quieras.
```bash
#Ingresa a la siguiente ruta y copialo
cat cgnat-wireguard/vps/config/peer2/peer2.conf
#De estaforma puedes obtener el QR
docker exec -it wireguard /app/show-peer 2
```

### 4. Ruta Estática Persistente

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
### Ping red Local y Tunnel

```bash
#Coloca tus ips
ping -c 4 192.168.50.1
ping -c 4 10.69.69.1

#Ping dentro del contenedor
sudo docker exec wireguard ping -c 4 192.168.50.1
sudo docker exec wireguard ping -c 4 10.69.69.1
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

### Instalacion de Ngnix Proxy Manager

Ingresa a la siguiente ubicacion:

```bash
cd cgnat-wireguard/nginx

#Levanta el contenedor
docker-compose up -d
```
### Probar respuesta 
```bash
#Entrar en NGNIX DESDE CONSOLA 
docker exec -it nginx-proxy-manager bash
#Ejemplo
curl -I http://192.168.50.1:80
```

<img width="894" height="391" alt="image" src="https://github.com/user-attachments/assets/374461cb-52df-4389-a9b2-61d6f12c2d84" />

>[!TIP]
Si el túnel no levanta o Ngnix no funcionan verifiquen las Políticas de firewall de su VPS.
