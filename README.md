# Generador de Certificados y Clientes IKEv2 (Sin Servidor)

Esta versión modificada del proyecto original `docker-ipsec-vpn-server` está adaptada para funcionar **exclusivamente como una herramienta generadora y administradora de certificados/perfiles IKEv2**, eliminando la ejecución del servidor VPN en segundo plano.

---

## 🎯 ¿Qué hace este proyecto realmente?

A diferencia de la imagen estándar (que levanta un túnel y demonios VPN como Libreswan y `xl2tpd` escuchando en puertos de red), esta variante:

1. **No levanta ningún servidor VPN ni abre túneles.**
2. **Actúa como una utilidad de línea de comandos (CLI)** para inicializar la Autoridad Certificadora (CA) y generar las credenciales de clientes IKEv2 (ficheros `.p12`, perfiles `.sswan` para Android, perfiles móviles y certificados `.cer`).
3. **Se ejecuta de forma efímera y segura** (generalmente con `--rm` y `--network none`), guardando los datos en un directorio o volumen local montado en `/etc/ipsec.d`.

---

## 📦 ¿Qué hace realmente el `Dockerfile`?

El archivo [`Dockerfile`](file:///C:/workspace/docker-ipsec-vpn-server/Dockerfile):

1. **Construcción y dependencias:**
   - Parte de una base ligera **Alpine Linux 3.23**.
   - Instala paquetes y herramientas de criptografía (`nss-tools`, `openssl`, `uuidgen`, etc.).
   - Descarga y compila el código fuente de **Libreswan 5.4** configurando el directorio de certificados NSS en `/etc/ipsec.d`.
   - Elimina los compiladores y cabeceras tras la compilación para mantener el tamaño de la imagen reducido.

2. **Personalización del script IKEv2:**
   - En lugar de descargar el script de internet durante la compilación, copia la versión local personalizada [`ikev2setup.sh`](file:///C:/workspace/docker-ipsec-vpn-server/ikev2setup.sh) como `/opt/src/ikev2.sh` y crea un enlace simbólico en `/usr/bin/ikev2.sh`.
   - Limpia posibles saltos de línea tipo Windows (`CRLF -> LF`) con `sed`.
   - Incluye modificaciones específicas (DML): exportación automática del certificado CA en formato `.cer`, del certificado de servidor `.p12`, de la lista de revocación `<CA_NAME>_revocation_list.crl` en formato PEM, y configuración adaptada de perfiles Android (`.sswan`), entre otros.

3. **Anulación del servidor VPN:**
   - Comenta la ejecución de `run.sh` (el script que originalmente levantaba los demonios VPN).
   - Configura como **`ENTRYPOINT`** a `/usr/bin/ikev2.sh` y como **`CMD`** por defecto `["--auto"]`.
   - Al iniciar el contenedor, ejecuta el asistente de configuración IKEv2 para crear la CA y generar clientes, finalizando en cuanto termina su tarea.

---

## 🛠️ ¿Qué hace realmente `build-local-DML.sh`?

El script [`build-local-DML.sh`](build-local-DML.sh) automatiza la compilación y etiquetado local de la imagen Docker:

1. **Configuración de variables:**
   - Nombre de imagen: `ipsec-vpn--without-server` (reflejando explícitamente que no ejecuta servidor).
   - Versión / Tag: `20260923`.
   - Plataforma destino: `linux/amd64` (por defecto).
   - Captura la fecha UTC actual (`BUILD_DATE`) y el hash corto del commit git actual (`VCS_REF`).

2. **Detección de usuario Docker:**
   - Obtiene automáticamente el nombre de usuario de Docker Desktop interactuando desde WSL con `docker-credential-desktop.exe`.

3. **Compilación (`docker buildx`):**
   - Construye la imagen con los argumentos de compilación requeridos (`BUILD_DATE`, `VCS_REF`, `VERSION`).
   - Aplica `--pull` para asegurar la última imagen base de Alpine.
   - Aplica `--load` para dejar la imagen disponible en el daemon local de Docker bajo la etiqueta `waltermelow/ipsec-vpn--without-server:latest`.

4. **Etiquetado adicional y subida opcional (`--push`):**
   - Genera etiquetas secundarias listas para Docker Hub:
     - `waltermelow/ipsec-vpn--without-server:20260923`
     - `waltermelow/ipsec-vpn--without-server:latest`
   - Si se ejecuta pasando el parámetro `--push` (o `-p` / `push`), publica automáticamente ambas etiquetas en Docker Hub (`docker push`).

---

## 🚀 Ejemplos de Uso

### 1. Compilar la imagen localmente (y opcionalmente subir a Docker Hub)

Desde WSL o entorno Linux/Bash:

```bash
# Solo compilar localmente
./build-local-DML.sh

# Compilar y hacer push a Docker Hub
./build-local-DML.sh --push
```

### 2. Inicializar la CA y generar el primer cliente

Ejecuta el contenedor de forma aislada (sin acceso a red) montando una carpeta local (por ejemplo `./ikev2-vpn-data`) donde se guardarán los certificados:

*(Variable opcional `-e VPN_ORG_NAME`: define el campo `O` (Organization) de los certificados y perfiles. Si no se especifica, por defecto: `VPN_IKEv2`.*
*Nombre de la CA: `CA_NAME`=`<VPN_ORG_NAME>_CA`, p.ej. `VPN_IKEv2_CA`, y se guarda en `/etc/ipsec.d/.vpnconfig` para operaciones posteriores).*

```bash
docker run --rm --network none \
  -e VPN_DNS_NAME=vpn.tudominio.com \
  -e VPN_CLIENT_NAME=cliente-1 \
  -e VPN_ORG_NAME=VPN_IKEv2 \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest
```

Alternativa: proyecto original `hwdsl2/ipsec-vpn-server`:
```bash
# Borrado previo:  mkdir -p "ikev2-vpn-data" && find "$(pwd)/ikev2-vpn-data" -mindepth 1 -delete
docker run --rm --network none -e VPN_DNS_NAME=midominio.com -e VPN_CLIENT_NAME=micliente -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" hwdsl2/ipsec-vpn-server /bin/sh -c 'ipsec initnss && /opt/src/ikev2.sh --auto && cd /etc/ipsec.d && certutil -L -d sql:. -n "IKEv2 VPN CA" -a -o IKEv2_VPN_CA.cer && pk12util -d sql:. -W "" -n "$VPN_DNS_NAME" -o "${VPN_DNS_NAME}.p12" && ls -alh'
```

*(Si se omite el argumento al final, ejecutará `--auto` por defecto).*

### 3. Añadir un nuevo cliente

```bash
docker run --rm --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --addclient "cliente-2"
```

### 4. Listar clientes existentes

```bash
docker run --rm --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --listclients
```

### 5. Exportar la configuración de un cliente existente

```bash
docker run --rm --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --exportclient "cliente-1"
```

### 6. Revocar un cliente existente

*(Nota: requiere modo interactivo `-it` para confirmar la operación, o pasar `-y` si aplica).*

```bash
docker run --rm -it --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --revokeclient "cliente-2"
```

Al revocar un cliente, además de actualizar la base de datos interna NSS (`cert9.db`) y eliminar los ficheros del cliente revocado, se genera/actualiza automáticamente el fichero de lista de revocación (CRL) en **formato PEM (Base64)** listo para importar en otros sistemas:
- `<carpeta_datos>/<CA_NAME>_revocation_list.crl` (p.ej: `./ikev2-vpn-data/VPN_IKEv2_CA_revocation_list.crl`)

### 7. Eliminar un cliente existente

```bash
docker run --rm -it --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --deleteclient "cliente-2"
```

### 8. Eliminar TODA la configuración IKEv2 (incluyendo CA, certificados y CRL)

```bash
docker run --rm -it --network none \
  -v "$(pwd)/ikev2-vpn-data:/etc/ipsec.d" \
  waltermelow/ipsec-vpn--without-server:latest --removeikev2
```
