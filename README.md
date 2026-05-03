# AWS-Lambda-Integration_IAC_EDDYCARRANZA

Procesamiento serverless de imágenes en AWS, desplegable en tres entornos con Terraform.
AWS-Lambda-Integration_IAC_EDDYCARRANZA
---

## ¿Qué hace este proyecto?

Cuando un usuario sube una imagen (JPG, PNG, GIF o WEBP), el sistema la recibe, la guarda en la nube y automáticamente la recorta a un círculo de 40×40 píxeles — como el avatar de un perfil de red social.

Todo esto ocurre sin servidores propios: AWS ejecuta el código solo cuando se necesita y apaga todo lo demás.

---

## ¿Cómo funciona por dentro?

```
Usuario  POST /upload (imagen)

API Gateway  punto de entrada público (HTTPS)

upload-lambda  valida y guarda la imagen original
 
S3 uploads   almacén de imágenes originales (se borran en 30 días)
  
SQS Queue  cola de tareas pendientes
  
crop-lambda   descarga, recorta a círculo 40×40 y guarda el resultado
  
S3 processed  almacén de imágenes procesadas (se borran en 90 días)


Si crop-lambda falla 3 veces:
  DLQ (cola de errores)  Alarma CloudWatch  Email de alerta
```
---

## Entornos disponibles

Entorno | Archivo de variables | Comando 

Desarrollo | `dev.tfvars` | `terraform apply -var-file="dev.tfvars"` 
QA | `qa.tfvars` | `terraform apply -var-file="qa.tfvars"` 
Producción | `prod.tfvars` | `terraform apply -var-file="prod.tfvars"` 

Cada entorno crea sus propios recursos con nombres únicos. 

---

## Estructura del proyecto

```
AWS-Lambda-Integration_IAC_EDDYCARRANZA/
│
├── src/                        ← Código fuente de las Lambdas
│   ├── upload-lambda/
│   │   ├── index.js            ← Recibe la imagen y la sube a S3
│   │   └── package.json
│   └── crop-lambda/
│       ├── index.js            ← Recorta la imagen a círculo 40×40
│       └── package.json
│
├── dist/                       ← ZIPs generados por build.sh (no subir a Git)
│
├── providers.tf                ← Configuración de AWS + nombres de recursos
├── variables.tf                ← Todas las variables del proyecto
├── vpc.tf                      ← Red privada (VPC, subnets, NAT Gateways)
├── vpc_endpoints.tf            ← Conexiones privadas a S3 y SQS
├── storage.tf                  ← Buckets S3 (uploads y processed)
├── messaging.tf                ← Cola SQS, DLQ y alarma de errores
├── iam.tf                      ← Permisos mínimos para cada Lambda
├── lambda.tf                   ← Funciones Lambda y su configuración
├── api_gateway.tf              ← API pública (POST /upload)
├── outputs.tf                  ← Muestra la URL y datos útiles al terminar
│
├── dev.tfvars                  ← Variables para DEV
├── qa.tfvars                   ← Variables para QA
├── prod.tfvars                 ← Variables para PROD
│
├── build.sh                    ← Empaqueta las Lambdas en ZIPs
├── terraform.exe               ← Ejecutable de Terraform (Windows)
└── .gitignore
```

---

## Requisitos previos

Antes de empezar necesitas tener instalado:

 Herramienta 
 Node.js  20  https://nodejs.org 
 AWS CLI v2 cualquiera  https://aws.amazon.com/cli 
 Terraform ≥ 1.6  incluido como `terraform.exe` en el proyecto 

---

## Paso a paso: despliegue completo

### 1. Clonar el repositorio

```bash
git clone https://github.com/eddycarranza/AWS-Lambda-Integration_IAC_EDDYCARRANZA.git
cd AWS-Lambda-Integration_IAC_EDDYCARRANZA
```

### 2. Configurar credenciales AWS

```bash
aws configure
# Ingresa tu Access Key ID
# Ingresa tu Secret Access Key
# Región: us-east-2
# Formato: json

# Verificar que funciona:
aws sts get-caller-identity
```

### 3. Empaquetar las Lambdas

```bash
# Desde Git Bash en Windows
./build.sh
```

Esto crea `dist/upload-lambda.zip` y `dist/crop-lambda.zip`.

### 4. Inicializar Terraform

```bash
./terraform.exe init
```

Solo se hace una vez. Descarga el proveedor de AWS localmente.

### 5. Crear workspace y desplegar en DEV

```bash
./terraform.exe workspace new dev
./terraform.exe apply -var-file="dev.tfvars"
# Escribe "yes" cuando lo pida
```

Al terminar verás la URL de la API y los nombres de los buckets.

### 6. Probar el endpoint

```bash
# El propio output te da el comando listo:
./terraform.exe output curl_example

# O manualmente:
curl -X POST "https://xxxx.execute-api.us-east-1.amazonaws.com/upload" \
     -F "file=@mi-foto.jpg"
```

Respuesta esperada:
```json
{ "success": true, "fileId": "uuid", "key": "uuid.jpg", "size": 12345 }
```

### 7. Verificar que la imagen fue procesada

```bash
aws s3 ls s3://$(./terraform.exe output -raw processed_bucket_name)/
```

Debe aparecer un archivo `_circular.png`.

### 8. Destruir todos los recursos

```bash
./terraform.exe destroy -var-file="dev.tfvars"
# Escribe "yes"
```

> Ambos buckets tienen `force_destroy = true` — se eliminan aunque tengan imágenes adentro.

---

## Múltiples entornos con Workspaces

Para manejar DEV, QA y PROD sin que sus estados se mezclen:

```bash
# Crear y desplegar cada entorno
./terraform.exe workspace new dev  && ./terraform.exe apply -var-file="dev.tfvars"
./terraform.exe workspace new qa   && ./terraform.exe apply -var-file="qa.tfvars"
./terraform.exe workspace new prod && ./terraform.exe apply -var-file="prod.tfvars"

# Ver todos los workspaces activos
./terraform.exe workspace list

# Destruir DEV
./terraform.exe workspace select dev
./terraform.exe destroy -var-file="dev.tfvars"
```

---

## ¿Cuánto cuesta?

Para pruebas cortas (2-3 minutos desplegado) el costo es mínimo:

Sobre la estimación de costos si levantamos esto por unos 3 minutos para hacer la prueba: toda la parte de los servicios principales (Lambda, S3, SQS y el API Gateway) no nos cuesta nada ($0.00) porque entra sobrado en la capa gratuita.
Lo que sí va a generar un cobro son los dos NAT Gateways, que salen aprox $0.09 porque AWS te cobra mínimo la hora entera así lo apagues al toque. A eso solo le sumas unos $0.02 por el VPC Endpoint de SQS. En total, la jugada sale por un estimado de $0.11 USD, así que no golpea la billetera para presentarlo.

Después de `terraform destroy` no queda ningún recurso activo y el cobro se detiene.

## Autor

**Eddy Carranza** — UPAO, Infraestructura como Código  

