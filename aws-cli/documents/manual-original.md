**HIBERUS**

**Manual de Gestión de Recursos en AWS**

Creación y gestión de recursos en la nube de AWS

  ------------------------------ ----------------------------------------
  **Versión**                    1.0

  **Plataforma**                 Consola de AWS

  **Fecha**                      2026

  **Clasificación**              **Confidencial - Uso Interno**

  **Fase**                       Fase 1 - Rendimiento (Seguridad en fase
                                 posterior)

  **Restricción critica**        **Sin modificación de código fuente -
                                 Aplicaciones de proveedor**
  ------------------------------ ----------------------------------------

**Tabla de Contenido**

[1. Introducción 4](#introducción)

[1.1 Propósito del documento 4](#propósito-del-documento)

[1.2 Contexto y descripción del Problema
4](#contexto-y-descripción-del-problema)

[1.3 Inventario de Application Pools - Solo Pools con Aplicaciones
4](#inventario-de-recursos)

[2. Resumen Ejecutivo de Hallazgos 6](#ingreso-a-la-consola-de-aws)

[3. Hallazgos Detallados y Soluciones
8](#administración-de-acceso-a-los-recursos-de-aws)

[3.1 Hallazgo 1 - maxconnection en System.Net: valor efectivo no
verificado 8](#__RefHeading___Toc14016_1134762081)

[Descripción del problema y aclaración técnica
8](#__RefHeading___Toc14018_1134762081)

[Estrategia de corrección - Solo en machine.config (sin tocar Web.config
del proveedor) 8](#__RefHeading___Toc14020_1134762081)

[3.2 Hallazgo 2 - serviceThrottling sin configuración en servicios WCF
REST 10](#__RefHeading___Toc14022_1134762081)

[Descripción del problema 10](#__RefHeading___Toc14024_1134762081)

[Estrategia de implementación - Dos niveles sin tocar código del
proveedor 10](#__RefHeading___Toc14026_1134762081)

[3.3 Hallazgos 3 y 4 - startMode OnDemand e idleTimeout
12](#__RefHeading___Toc14028_1134762081)

[Descripción del Problema 12](#__RefHeading___Toc14030_1134762081)

[Archivo a Modificar 12](#__RefHeading___Toc14032_1134762081)

[3.4 Hallazgo 5 - enable32BitAppOnWin64 innecesario en Pools de
Servicios 13](#__RefHeading___Toc14034_1134762081)

[Descripción del Problema 13](#__RefHeading___Toc14036_1134762081)

[Pools a Analizar - Decisión Condicionada a Verificación con Proveedor
13](#__RefHeading___Toc14038_1134762081)

[3.5 Hallazgo 6 - compilation debug en Web.config de Producción
14](#__RefHeading___Toc14040_1134762081)

[Descripción del Problema 14](#__RefHeading___Toc14042_1134762081)

[Archivos a Verificar 14](#__RefHeading___Toc14044_1134762081)

[3.6 Hallazgos 7 y 8 - CDN sin Cache y Tiempos de Respuesta de 1,000,000
ms 15](#__RefHeading___Toc14046_1134762081)

[Descripción del Problema - Tiempos Extremos y Saturación del Thread
Pool 15](#__RefHeading___Toc14048_1134762081)

[Descripción del Problema - Ausencia de Cache
15](#__RefHeading___Toc14050_1134762081)

[Archivos a Modificar 15](#__RefHeading___Toc14052_1134762081)

[3.7 Hallazgo 9 - MIME Types JSON no Incluidos en Compresión Dinámica
17](#__RefHeading___Toc14054_1134762081)

[Descripción del Problema 17](#__RefHeading___Toc14056_1134762081)

[3.8 Hallazgos 10, 11 y 12 - queueLength, webLimits y
appConcurrentRequestLimit 18](#__RefHeading___Toc14058_1134762081)

[Descripción del Problema - queueLength
18](#__RefHeading___Toc14060_1134762081)

[Descripción del Problema - webLimits y appConcurrentRequestLimit
18](#__RefHeading___Toc14062_1134762081)

[3.9 Hallazgo 13 - Reciclajes sin Horario Programado
20](#__RefHeading___Toc14064_1134762081)

[Descripción del Problema 20](#__RefHeading___Toc14066_1134762081)

[3.10 Recomendaciones adicionales
21](#__RefHeading___Toc14064_1134762081_Copia)

[Descripción del Problema 21](#__RefHeading___Toc14066_1134762081_Copia)

[4. Plan de Implementación por Fases
22](#__RefHeading___Toc14068_1134762081)

[5. Referencias Oficiales Microsoft
24](#__RefHeading___Toc14070_1134762081)

[6. Glosario 25](#__RefHeading___Toc14072_1134762081)

# 1. Introducción

## 1.1 Propósito del documento

El presente documento tiene como objetivo describir la infraestructura
cloud implementada en Amazon Web Services (AWS) para el proyecto
Multicines, detallando cada uno de los componentes configurados, las
decisiones técnicas tomadas y los pasos necesarios para la
administración y operación de los recursos. Este documento sirve como
referencia técnica oficial para el equipo de Multicines y como guía para
la gestión continua de la plataforma en la nube.

## 1.2 Contexto y descripción del Problema

Multicines requiere exponer su sistema de gestión de cines Vista API
Connect, basado en tecnología IIS 10, Windows Server 2016 y WCF/.svc,
hacia servicios externos de forma segura y controlada. Para ello se
diseñó e implementó una capa de integración en AWS que actúa como
intermediaria entre los consumidores externos y el sistema on-premise
del datacenter de Multicines, garantizando disponibilidad, seguridad y
trazabilidad de las comunicaciones.

La solución contempla dos ambientes independientes --- desarrollo y
producción --- conectados al datacenter mediante VPN Site-to-Site, con
despliegues automatizados a través de pipelines de CI/CD.

## 1.3 Inventario de Recursos

A continuación, se detallan los recursos aprovisionados en la cuenta AWS
de Multicines (340271092920), región us-east-1 (Norte de Virginia):

  ---------------------------------------------------------------------------------------
  **Recurso**       **Nombre**                                             **Ambiente**
  ----------------- -------------------------------- --------------------- --------------
  VPC               vpc-multicines-dev                                     dev

  Subred pública    subnet-dev-public-az1a                                 dev
  zona A                                                                   

  Subred pública    subnet-dev-public-az1b                                 dev
  zona B                                                                   

  Subred privada    subnet-dev-private-az1a                                dev

  Internet Gateway  dev-igw                                                dev

  NAT Gateway       dev-nav                                                dev

  Virtual Private   dev-vgw                                                dev
  Gateway                                                                  

  Tabla de          dev-rtb-public                                         dev
  enrutamiento                                                             

  Tabla de          dev-rtb-private                                        dev
  enrutamiento                                                             

  Grupo de          dev-sg-alb                                             dev
  seguridad                                                                

  Grupo de          dev-sg-ecs                                             dev
  seguridad                                                                

  Task Definition   dev-multicines-integration                             dev

  VPC               prod-vpc-multicines                                    prod

  Subred pública    prod-subnet-public-1a                                  prod
  zona A                                                                   

  Subred pública    prod-subnet-public-1b                                  prod
  zona B                                                                   

  Subred privada    prod-subnet-private-1a                                 prod

  Subred privada    prod-subnet-private-1b                                 prod

  Internet Gateway  prod-igw-multicines                                    prod

  NAT Gateway       prod-nat-1a                                            prod

  NAT Gateway       prod-nat-1b                                            prod

  Virtual Private   prod-vgw-multicines                                    prod
  Gateway                                                                  

  Tabla de          prod-rtb-public                                        prod
  enrutamiento                                                             

  Tabla de          prod-rtb-private-1a                                    prod
  enrutamiento                                                             

  Tabla de          prod-rtb-private-1b                                    prod
  enrutamiento                                                             

  Grupo de          prod-sg-alb                                            prod
  seguridad                                                                

  Grupo de          prod-sg-ecs                                            prod
  seguridad                                                                

  Task Definition   prod-multicines-integration                            prod

  ECR               multicines/integration-service                         ambos

  ECS Cluster       multicines-cluster                                     ambos

  Task Definition   prod-multicines-integration                            ambos

  Rol IAM           multicines-github-actions-role                         ambos
  ---------------------------------------------------------------------------------------

# 2. Ingreso a la consola de AWS

Para ingresar a la consola de AWS, debemos abrir el navegador de nuestra
preferencia y buscar *AWS console login*, o también podemos hacer clic
en el enlace que se encuentra a continuación

[Amazon Web Services
Sign-In](https://signin.aws.amazon.com/signin?redirect_uri=https%3A%2F%2Fus-east-1.console.aws.amazon.com%2Fiam%2Fhome%3Fca-oauth-flow-id%3Da3e2%26hashArgs%3D%2523%252Fusers%26isauthcode%3Dtrue%26oauthStart%3D1781285015074%26region%3Dus-east-1%26state%3DhashArgsFromTB_us-east-1_3f22d1e7a2922263&client_id=arn%3Aaws%3Asignin%3A%3A%3Aconsole%2Fiamv2&forceMobileApp=0&code_challenge=cFBUFRIcvAxlxqxE_QAaGMJqNdYiSwYm_ErcM9hRa_U&code_challenge_method=SHA-256)

Al hacer clic o ingresar a la consola, se mostrará lo siguiente:

![](documents/images/media/image.png){width="5.90625in"
height="3.8333333333333335in"}

## 2.1 Ingreso con usuario root

Seleccionamos la opción *Root user*, escribimos la dirección de correo
electrónico y luego hacemos clic en *Next* o *Siguiente*:

![](documents/images/media/image2.png){width="5.90625in"
height="3.2291666666666665in"}

Al hacer clic en *Next* o *Siguiente*, se mostrará en pantalla un cuadro
para ingresar la contraseña del usuario root.

![](documents/images/media/image3.png){width="5.90625in"
height="3.6875in"}

Luego, se nos solicitará ingresar el código de autenticación, el cual
debió ser configurado

previamente al iniciar sesión por primera vez.

![](documents/images/media/image4.png){width="5.90625in"
height="3.5416666666666665in"}

Luego de ingresar el código y hacer clic en *Sign in* o *Ingresar*, si
la autenticación se realizó de forma exitosa, seremos redirigidos
automáticamente a la siguiente vista.

![](documents/images/media/image5.png){width="5.90625in"
height="3.1458333333333335in"}

## 2.2 Inicio de sesión con usuario IAM

Debe contar con credenciales de usuario IAM; estas credenciales son
generadas por el usuario root.

Seleccionar la opción *IAM user*, escribir el ID de la cuenta ---es un
identificador de 12 dígitos--- y luego hacer clic en el botón *Next* o
*Siguiente*.

## 

![](documents/images/media/image6.png){width="5.90625in"
height="4.0625in"}

Ingrese las credenciales, como el *IAM username* y la contraseña, y
luego haga clic en *Sign in* o *Ingresar*.

![](documents/images/media/image7.png){width="5.90625in"
height="4.020833333333333in"}

Si las credenciales son correctas y la autenticación se realiza de forma
exitosa, se mostrará

la siguiente pantalla.

![](documents/images/media/image8.png){width="5.90625in"
height="3.1145833333333335in"}

# 3. Administración de acceso a los recursos de AWS

## 3.1 IAM

IAM nos permite administrar grupos, usuarios, roles y políticas, y
analizar el acceso a la plataforma. Para acceder, debemos dirigirnos a
la barra de búsqueda y escribir *IAM*, luego hacemos clic para
administrar los accesos a los recursos de la nube de AWS.

![](documents/images/media/image9.png){width="5.90625in"
height="3.46875in"}

El panel de administración se muestra en la siguiente imagen; en la
parte lateral izquierda se encuentran todas las opciones disponibles.

![](documents/images/media/imagea.png){width="5.90625in"
height="3.4583333333333335in"}

## 3.2 Administrar Grupos IAM

Los grupos IAM permiten administrar los permisos de varios usuarios de
forma centralizada. En la siguiente imagen se muestra la vista de
administración de grupos de usuarios de IAM.

![](documents/images/media/imageb.png){width="5.90625in"
height="3.1354166666666665in"}

### 3.2.1 Creación de un grupo IAM

Para crear un grupo, debemos dirigirnos al panel lateral izquierdo y
seleccionar la opción *User groups*, luego hacemos clic en *Create
group*.

![](documents/images/media/imagec.png){width="5.90625in"
height="3.0729166666666665in"}

Ingresamos el nombre del grupo en el campo *User group name* y,
opcionalmente, asignamos las políticas de permisos correspondientes en
la sección *Attach permissions policies*. Finalmente, hacemos clic en
*Create user group* para completar la creación.

## ![](documents/images/media/imaged.png){width="5.90625in" height="2.71875in"}

## ![](documents/images/media/imagee.png){width="5.90625in" height="2.2142913385826772in"}

## ![](documents/images/media/imagef.png){width="5.90625in" height="2.9791666666666665in"}

En la siguiente imagen podemos visualizar la creación exitosa del grupo.

## ![](documents/images/media/image10.png){width="5.90625in" height="1.9479166666666667in"}

### 3.2.2 Editar Grupo IAM

Acceder a Grupos de usuarios de IAM y hacer clic en el grupo a editar

![](documents/images/media/image11.png){width="5.90625in"
height="3.09375in"}

Para agregar personas al grupo debemos hacer clic en el botón Agregar
personas, se mostrarán los usuarios y debemos seleccionar los usuarios a
agregar al grupo.

![](documents/images/media/image12.png){width="5.90625in"
height="2.6770833333333335in"}

### 3.2.3 Administrar usuarios IAM

Para crear un usuario IAM, debemos dirigirnos al panel lateral izquierdo
y seleccionar la opción *Users*, luego hacemos clic en *Create user*.

![](documents/images/media/image13.png){width="5.90625in"
height="3.1458333333333335in"}

Ingresamos el nombre del usuario en el campo *User name*. Si el usuario
necesita acceder a la consola de AWS, habilitamos la opción *Provide
user access to the AWS Management Console*. Luego hacemos clic en *Next*
para continuar.

![](documents/images/media/image14.png){width="5.90625in"
height="3.0104166666666665in"}

![](documents/images/media/image15.png){width="5.90625in"
height="2.9895833333333335in"}

### 3.2.3 Asignación de un usuario a un grupo

En el siguiente paso, seleccionamos la opción *Add user to group* para
asignar el usuario al grupo creado previamente.

![](documents/images/media/image16.png){width="5.90625in"
height="2.9583333333333335in"}

Seleccionamos el grupo correspondiente de la lista y hacemos clic en
*Next* para continuar.

![](documents/images/media/image17.png){width="5.90625in"
height="2.9479166666666665in"}

![](documents/images/media/image18.png){width="5.90625in"
height="2.9479166666666665in"}

Se mostrará un resumen con la configuración del usuario. Si los datos
son correctos, hacemos clic en *Create user o Crear persona para
finalizar.*

![](documents/images/media/image19.png){width="5.90625in"
height="3.1041666666666665in"}

![](documents/images/media/image1a.png){width="5.90625in"
height="2.9375in"}

Hacer clic en Descargar archivo.csv para descargar las credenciales de
inicio de sesión.

![](documents/images/media/image1b.png){width="5.90625in"
height="3.1145833333333335in"}

Al abrir el archivo encontramos el nombre de usuario, contraseña y el
link para acceder a la consola de AWS.

![](documents/images/media/image1c.png){width="5.90625in"
height="0.4791666666666667in"}

Al hacer clic en Volver a la lista de personas visualizaremos todos los
usuarios IAM existentes.

![](documents/images/media/image1d.png){width="5.90625in"
height="2.7395833333333335in"}

### 3.2.4 Administrar Políticas IAM

Las políticas definen los permisos que tendrá un usuario o grupo sobre
los recursos de AWS. Para asignar una política, debemos dirigirnos al
panel lateral izquierdo y seleccionar *Policies o Políticas*.

![](documents/images/media/image1e.png){width="5.90625in"
height="3.0833333333333335in"}

Buscamos la política deseada en la barra de búsqueda, seleccionamos la
casilla correspondiente y hacemos clic en *Attach*. También es posible
asignar políticas directamente desde la configuración del usuario o del
grupo, en la pestaña *Permissions*.

Podemos asociar políticas a usuarios o grupos, en la siguiente vista
elegimos el grupo o el usuario al que deseamos asignar las políticas
previamente seleccionadas y hacemos clic en Asociar política.

![](documents/images/media/image1f.png){width="5.90625in"
height="3.1041666666666665in"}

# Administración de VPC (Nube privada virtual)

## Creación de una VPC

Una VPC (*Virtual Private Cloud*) es una red virtual privada dentro de
AWS que nos permite aislar y controlar los recursos de la nube. Para
crear una VPC, debemos dirigirnos a la barra de búsqueda de la consola
de AWS, escribir *VPC* y hacer clic en el servicio.

![](documents/images/media/image20.png){width="5.90625in"
height="2.96875in"}

En el panel lateral izquierdo seleccionamos la opción *Your VPC* o *Sus
VPC* y luego hacemos clic en *Create VPC o Crear VPC*.

![](documents/images/media/image21.png){width="5.90625in"
height="3.1145833333333335in"}

En la pantalla de configuración seleccionamos la opción *VPC and more*,
la cual nos permite crear la VPC junto con sus recursos de red de forma
automática. A continuación, configuramos los siguientes parámetros:

- **Name tag:** ingresamos el nombre que identificará la VPC.

- **IPv4 CIDR block:** definimos el rango de direcciones IP de la red,
  por ejemplo *10.0.0.0/16*.

- **Number of Availability Zones:** seleccionamos *2*, ya que contamos
  con dos zonas de disponibilidad.

- **Number of public subnets:** definimos la cantidad de subredes
  públicas, una por cada zona de disponibilidad.

- **Number of private subnets:** definimos la cantidad de subredes
  privadas, una por cada zona de disponibilidad.

- **NAT gateways:** seleccionamos la opción según las necesidades del
  proyecto.

- **VPC endpoints:** configuramos según los servicios que se vayan a
  utilizar.

Una vez completada la configuración, hacemos clic en *Create VPC*. Si la
creación se realizó de forma exitosa, se mostrará un resumen con todos
los recursos creados, incluyendo las subredes, tablas de rutas e
internet gateway asociados a la VPC.

**Nota:** Esta configuración debe realizarla el equipo técnico o debe
estar previamente definida.

![](documents/images/media/image22.png){width="5.90625in"
height="2.9375in"}

![](documents/images/media/image23.png){width="5.90625in"
height="2.9166666666666665in"}

![](documents/images/media/image24.png){width="5.90625in"
height="2.9479166666666665in"}

![](documents/images/media/image25.png){width="5.90625in"
height="2.9895833333333335in"}

## Configuración de VPCs y subredes 

El proyecto cuenta con dos VPCs independientes, una para el ambiente de
desarrollo y otra para el ambiente de producción, se encuentran
desplegadas en las regiones us-east-1a y us-east-2a con el objetivo de
garantizar alta disponibilidad.

![](documents/images/media/image26.png){width="5.90625in"
height="2.6770833333333335in"}

![](documents/images/media/image27.png){width="5.90625in"
height="3.0in"}

![](documents/images/media/image28.png){width="5.90625in"
height="3.0208333333333335in"}

![](documents/images/media/image29.png){width="5.90625in"
height="3.59375in"}

![](documents/images/media/image2a.png){width="5.90625in"
height="2.9791666666666665in"}

## Creación del internet gateway

El *Internet Gateway* permite la comunicación entre los recursos de la
VPC y el internet. Para crearlo, nos dirigimos a la consola de AWS, en
la barra de búsqueda escribimos *VPC* y en el panel lateral izquierdo
seleccionamos *Puertas de enlace de Internet*. Hacemos clic en *Crear
gateway de Internet* y configuramos los siguientes parámetros:

- **Etiqueta de nombre:** ingresamos el nombre del Internet Gateway,
  siguiendo la convención del proyecto:

  - Para dev: *dev-igw*

  - Para prod: *prod-igw-multicines*

Hacemos clic en *Crear gateway de Internet*.

![](documents/images/media/image2b.png){width="5.90625in"
height="2.09375in"}

### Asociar el internet Gateway a la VPC

Una vez creado, el Internet Gateway se encuentra en estado *Detached*.
Para asociarlo a la VPC, seleccionamos el gateway recién creado, hacemos
clic en *Acciones* → *Asociar a VPC* y seleccionamos la VPC
correspondiente:

- Para dev: *vpc-multicines-dev*

- Para prod: *prod-vpc-multicines*

Hacemos clic en *Asociar gateway de Internet*. Si la operación fue
exitosa, el estado cambiará a *Attached*.

![](documents/images/media/image2c.png){width="5.90625in"
height="1.7083333333333333in"}

## Creación de NAT Gateway

El *NAT Gateway* permite que los recursos de las subredes privadas
puedan acceder a internet de forma saliente sin exponer sus direcciones
IP. Para crearlo, nos dirigimos al panel lateral izquierdo de la consola
VPC y seleccionamos *Gateways NAT*. Hacemos clic en *Crear gateway NAT*
y configuramos los siguientes parámetros:

- **Nombre:** ingresamos el nombre del NAT Gateway siguiendo la
  convención del proyecto.

- **Subred:** seleccionamos la subred **pública** correspondiente --- el
  NAT Gateway siempre se crea en la subred pública.

- **Tipo de conectividad:** seleccionamos *Público*.

- **ID de asignación de IP elástica:** hacemos clic en *Asignar IP
  elástica* para generar automáticamente una IP pública fija.

![](documents/images/media/image2d.png){width="5.90625in"
height="2.4479166666666665in"}

![](documents/images/media/image2e.png){width="5.90625in"
height="3.0416666666666665in"}

![](documents/images/media/image2f.png){width="5.90625in"
height="2.8020833333333335in"}

### NAT Gateways del proyecto

El proyecto cuenta con los siguientes NAT Gateways:

  ----------------- ------------------------ --------------------- --------------
  **Nombre**        **Subred**                                     **Ambiente**

  nat-dev           subnet-dev-public-az1a                         dev

  nat-prod-1a       subnet-dev-public-1a                           dev

  Nat-prod-1b       subnet-dev-public-1b                           dev
  ----------------- ------------------------ --------------------- --------------

**Nota:** para prod se crearon dos NAT Gateways, uno por cada zona de
disponibilidad, para garantizar alta disponibilidad y evitar costos de
transferencia de datos entre zonas.

### Actualización de las tablas de enrutamiento

Una vez creados los NAT Gateways, se actualizaron las tablas de
enrutamiento de las subredes privadas agregando la siguiente ruta en
cada una:

- **Destino:** *0.0.0.0/0*

- **Target:** NAT Gateway de la zona de disponibilidad correspondiente

Esto garantiza que todo el tráfico saliente de las subredes privadas
pase a través del NAT Gateway de su misma zona.

## Grupos de seguridad

Los grupos de seguridad actúan como firewall virtual que controla el
tráfico de entrada y salida de los recursos. Para crearlos, nos
dirigimos al panel lateral izquierdo de la consola VPC, seleccionamos
*Grupos de seguridad* y hacemos clic en *Crear grupo de seguridad*.

![](documents/images/media/image30.png){width="5.90625in"
height="1.8614031058617673in"}

### Grupo de seguridad --- ALB

Este grupo controla el tráfico que llega al balanceador de carga desde
internet.

- **Nombre:** *sg-alb-dev* / *sg-alb-prod*

- **VPC:** seleccionamos la VPC correspondiente

**Reglas de entrada:**

  ----------------- --------------------- --------------------- ------------
  **Tipo**          **Protocolo**         **Puerto**            **Origen**

  HTTPS             TCP                   443                   0.0.0.0/0

  HTTP              TCP                   80                    0.0.0.0/0
  ----------------- --------------------- --------------------- ------------

**Reglas de salida:**

  ----------------- --------------------- --------------------- -------------
  **Tipo**          **Protocolo**         **Puerto**            **Destino**

  Todo el tráfico   Todos                 Todos                 0.0.0.0/0
  ----------------- --------------------- --------------------- -------------

![](documents/images/media/image31.png){width="5.90625in"
height="2.5in"}

![](documents/images/media/image32.png){width="5.90625in"
height="2.7708333333333335in"}

**Grupo de seguridad --- ECS Fargate**

Este grupo controla el tráfico que llega a los contenedores. Solo
permite tráfico proveniente del ALB en el puerto de la aplicación.

- **Nombre:** *sg-ecs-dev* / *sg-ecs-prod*

- **VPC:** seleccionamos la VPC correspondiente

**Reglas de entrada:**

  ----------------- --------------------- ------------ ---------------------
  **Tipo**          **Protocolo**         **Puerto**   **Origen**

  TCP personalizado TCP                   8095         sg-alb-dev /
                                                       sg-alb-prod
  ----------------- --------------------- ------------ ---------------------

**Nota:** el origen referencia directamente al grupo de seguridad del
ALB, no a un rango de IPs. Esto garantiza que solo el ALB pueda enviar
tráfico a los contenedores.

**Reglas de salida:**

  ----------------- --------------------- --------------------- -------------
  **Tipo**          **Protocolo**         **Puerto**            **Destino**

  Todo el tráfico   Todos                 Todos                 0.0.0.0/0
  ----------------- --------------------- --------------------- -------------

![](documents/images/media/image33.png){width="5.90625in"
height="2.84375in"}

![](documents/images/media/image34.png){width="5.90625in"
height="2.8333333333333335in"}

**Tablas de enrutamiento**

Las tablas de enrutamiento definen hacia dónde se dirige el tráfico de
cada subred. El proyecto cuenta con las siguientes tablas configuradas:

**Dev**

+:-----------------+:------------------------+:------------------------------+
| **Tipo**         | **Protocolo**           | **Rutas configuradas**        |
+------------------+-------------------------+-------------------------------+
| dev-rtb-public   | subnet-dev-public-az1a  | 0.0.0.0/0 → IGW, rutas        |
|                  |                         | locales                       |
|                  | subnet-dev-public-az1b  |                               |
+------------------+-------------------------+-------------------------------+
| dev-rtb-private  | dev-subnet-private-az1a | 0.0.0.0/0 → NAT,              |
|                  |                         | 192.168.0.0/16 → VGW, rutas   |
|                  |                         | locales                       |
+------------------+-------------------------+-------------------------------+

**Prod**

+:-------------------------------+:-----------------------+:------------------------------+
| **Tipo**                       | **Protocolo**          | **Rutas configuradas**        |
+--------------------------------+------------------------+-------------------------------+
| dev-rtb-public                 | prod-subnet-public-1a  | 0.0.0.0/0 → IGW, rutas        |
|                                |                        | locales                       |
|                                | prod-subnet-public-1b  |                               |
+--------------------------------+------------------------+-------------------------------+
| prod-rtb-multicines-private-1a | prod-subnet-public-1a  | 0.0.0.0/0 → NAT 1a, rutas     |
|                                |                        | locales                       |
|                                | prod-subnet-public-1b  |                               |
+--------------------------------+------------------------+-------------------------------+
| prod-rtb-multicines-private-1b | prod-subnet-private-1b | 0.0.0.0/0 → NAT 1b, rutas     |
|                                |                        | locales                       |
+--------------------------------+------------------------+-------------------------------+

Para crear cada tabla de enrutamiento, nos dirigimos a *Tablas de
enrutamiento* en el panel lateral izquierdo y hacemos clic en *Crear
tabla de enrutamiento*. Configuramos el nombre y la VPC correspondiente,
luego en la pestaña *Rutas* hacemos clic en *Editar rutas* para agregar
las rutas necesarias, y finalmente en la pestaña *Asociaciones de
subredes* asociamos explícitamente las subredes correspondientes.

![](documents/images/media/image35.png){width="5.90625in"
height="2.1041666666666665in"}

![](documents/images/media/image36.png){width="5.90625in"
height="2.8229166666666665in"}

![](documents/images/media/image37.png){width="5.90625in"
height="1.84375in"}

![](documents/images/media/image38.png){width="5.90625in"
height="2.90625in"}

![](documents/images/media/image39.png){width="5.90625in"
height="1.9895833333333333in"}

## Elastic Container Registry (ECR)

Buscamos el servicio Elastic Container Registry en la barra de búsqueda
de la consola de AWS.

![](documents/images/media/image3a.png){width="5.90625in"
height="3.3125in"}

El Elastic Container Registry es el repositorio privado de AWS donde se
almacenan las imágenes Docker del proyecto. Para crearlo, en la barra de
búsqueda de la consola escribimos ECR y hacemos clic en Crear
repositorio.

![](documents/images/media/image3b.png){width="5.90625in"
height="3.09375in"}

Configuramos los siguientes parámetros:

- Visibilidad: Privado

- Nombre del repositorio: multicines/integration-service

- Mutabilidad de etiquetas: Immutable --- evita sobreescribir imágenes
  con el mismo tag

- Cifrado: AES-256

![](documents/images/media/image3c.png){width="5.90625in"
height="3.1041666666666665in"}

Hacemos clic en Crear repositorio.

![](documents/images/media/image3d.png){width="5.90625in"
height="3.1145833333333335in"}

Una vez creado, la URI del repositorio queda de la siguiente forma:

340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service

Las imágenes se etiquetan de la siguiente manera según el ambiente:

![](documents/images/media/image3e.png){width="5.90625in"
height="3.2916666666666665in"}

## Elastic Container Service ECS

**Elastic Container Service (ECS)**

ECS es el servicio de AWS que permite ejecutar y administrar
contenedores Docker. El proyecto utiliza *AWS Fargate* como tipo de
lanzamiento, lo que elimina la necesidad de administrar servidores.

![](documents/images/media/image3f.png){width="5.90625in"
height="1.9028073053368328in"}

**Creación del cluster**

En la consola buscamos *ECS* y hacemos clic en *Crear clúster*.
Configuramos:

- **Nombre del clúster:** *multicines-cluster*

- **Infraestructura:** *Solo Fargate*

- **Monitoreo:** *Container Insights* activado

![](documents/images/media/image40.png){width="5.90625in"
height="3.1354166666666665in"}

![](documents/images/media/image41.png){width="5.90625in"
height="3.1145833333333335in"}

Hacemos clic en *Crear*.

![](documents/images/media/image42.png){width="5.90625in"
height="3.125in"}

**Nota:** antes de crear el cluster es necesario que el rol
*AWSServiceRoleForECS* exista en la cuenta. Si no existe, se debe crear
desde IAM seleccionando *Elastic Container Service* como caso de uso.

![](documents/images/media/image43.png){width="5.90625in"
height="1.7534787839020123in"}

## Definición de Tareas

Las *Task Definitions* definen los parámetros de ejecución del
contenedor.

![](documents/images/media/image44.png){width="5.90625in"
height="3.09375in"}

Para definir una tarea hacer clic en el botón Crear una nueva definición
de tarea.

Se crearon dos, una por ambiente:

**Dev --- dev-multicines-integration**

  --------------------------------- ------------------------------------
  **Parámetro**                     **Valor**

  Tipo de lanzamiento               AWS Fargate

  CPU                               0.5 vCPU

  Memoria                           1GB

  Nombre del contenedor             dev-integrator

  Puerto                            8095

  Rol de tarea                      multicines-ecs-task-role

  Rol de ejecución                  ecsTaskExecutionRole

  Log group                         /ecs/dev-multicines-integration
  --------------------------------- ------------------------------------

![](documents/images/media/image45.png){width="5.90625in"
height="2.8541666666666665in"}

![](documents/images/media/image46.png){width="5.90625in"
height="2.7604166666666665in"}

**Prod --- prod-multicines-integration**

  --------------------------------- ------------------------------------
  **Parámetro**                     **Valor**

  Tipo de lanzamiento               AWS Fargate

  CPU                               1 vCPU

  Memoria                           3GB

  Nombre del contenedor             prod-integrator

  Puerto                            8095

  Rol de tarea                      multicines-ecs-task-role

  Rol de ejecución                  ecsTaskExecutionRole

  Log group                         /ecs/prod-multicines-integration
  --------------------------------- ------------------------------------

![](documents/images/media/image47.png){width="5.90625in"
height="3.0833333333333335in"}

### Variables de entorno configuradas

Las siguientes variables de entorno se configuraron directamente en cada
Task Definition:

  ------------------------ ------------------------ ------------------------
  **Variable**             **Dev**                  **Prod**

  SPRING_PROFILES_ACTIVE   dev                      prod

  AWS_REGION               us-east-1                us-east-1

  OTEL_LOGS_EXPORTER       none                     none

  OTEL_METRICS_EXPORTER    none                     none

  OTEL_TRACES_EXPORTER     SSM Parameter Store      SSM Parameter Store
  ------------------------ ------------------------ ------------------------

![](documents/images/media/image48.png){width="5.90625in"
height="3.25in"}

![](documents/images/media/image49.png){width="5.90625in"
height="2.875in"}

Para crear cada Task Definition, en el panel lateral de ECS
seleccionamos Definiciones de tareas → Crear nueva definición de tarea y
completamos los parámetros indicados en las tablas anteriores.

![](documents/images/media/image4a.png){width="5.90625in"
height="3.09375in"}

![](documents/images/media/image4b.png){width="5.90625in"
height="3.2708333333333335in"}

## Proveedor de identicas OIDC para GitHub Actions

Para permitir que GitHub Actions se autentique con AWS sin necesidad de
claves de acceso estáticas, se configuró un proveedor de identidad
*OpenID Connect (OIDC)* que establece una relación de confianza entre
GitHub y AWS.

**Creación del proveedor de identidad**

En la consola de AWS buscamos *IAM* y en el panel lateral izquierdo
seleccionamos

*Proveedores de identidad* → *Agregar proveedor*. Configuramos los
siguientes parámetros:

- **Tipo de proveedor:** *OpenID Connect*

- **URL del proveedor:** <https://token.actions.githubusercontent.com>

- **Audiencia:** sts.amazonaws.com

![](documents/images/media/image4c.png){width="5.90625in"
height="2.156251093613298in"}

Hacemos clic en *Agregar proveedor*.

![](documents/images/media/image4d.png){width="5.90625in"
height="3.09375in"}

![](documents/images/media/image4e.png){width="5.90625in"
height="3.09375in"}

## Creación del rol IAM con OIDC

Una vez creado el proveedor, creamos el rol que GitHub Actions asumirá
durante los despliegues.

En IAM seleccionamos *Roles* → *Crear rol* y configuramos:

- **Tipo de entidad:** *Identidad web*

- **Proveedor de identidad:** token.actions.githubusercontent.com

- **Audiencia:** sts.amazonaws.com

- **GitHub organization:** Multicines

- **GitHub repository:** Capa-Media

- **GitHub branch:** \* (todas las ramas)

En el paso de permisos agregamos las siguientes políticas:

  ------------------------------------- ------------------------------------
  **Política**                          **Propósito**

  AmazonECS_FullAccess                  Gestionar servicios y tareas ECS

  AmazonEC2ContainerRegistryPowerUser   Push y pull de imágenes en ECR
  ------------------------------------- ------------------------------------

En el paso final asignamos el nombre del rol:

- **Nombre:** multicines-github-actions-role

- **Descripción:** Rol para GitHub Actions con acceso a ECS y ECR

- **ARN:** arn:aws:iam::340271092920:role/multicines-github-actions-role

**Variables y secretos configurados en GitHub**

Para que los pipelines puedan referenciar los recursos de AWS, se
configuraron las siguientes variables y secretos en el repositorio
*Capa-Media* bajo *Settings* → *Secrets and variables* → *Actions*:

**Variables --- Repository variables:**

  --------------------------------- ------------------------------------
  **Política**                      **Propósito**

  AWS_REGION                        us-east-1

  ECR_REPOSITORY                    multicines/integration-service

  ECS_CLUSTER                       multicines-cluster

  DEV_TASK_DEFINITION               dev-multicines-integration

  PROD_TASK_DEFINITION              prod-multicines-integration

  DEV_ECS_SERVICE                   dev-multicines-service

  PROD_ECS_SERVICE                  prod-multicines-service
  --------------------------------- ------------------------------------

Secrets

  --------------------------------- ---------------------------------------------------------------
  **Secret**                        **Valor**

  AWS_ROLE_ARN                      arn:aws:iam::340271092920:role/multicines-github-actions-role
  --------------------------------- ---------------------------------------------------------------

![](documents/images/media/image4f.png){width="5.90625in"
height="3.09375in"}

![](documents/images/media/image50.png){width="5.90625in"
height="3.2604166666666665in"}

![](documents/images/media/image51.png){width="5.90625in"
height="3.1041666666666665in"}

![](documents/images/media/image52.png){width="5.90625in"
height="2.8958333333333335in"}

![](documents/images/media/image53.png){width="5.90625in"
height="3.125in"}

![](documents/images/media/image54.png){width="5.90625in"
height="1.8333333333333333in"}

## Protección de ramas

![](documents/images/media/image55.png){width="5.90625in"
height="3.1145833333333335in"}

![](documents/images/media/image56.png){width="5.90625in"
height="3.28125in"}

![](documents/images/media/image57.png){width="5.90625in"
height="3.0416666666666665in"}

![](documents/images/media/image58.png){width="5.90625in"
height="3.1458333333333335in"}

![](documents/images/media/image59.png){width="5.90625in"
height="3.1354166666666665in"}

![](documents/images/media/image5a.png){width="5.90625in"
height="3.125in"}

![](documents/images/media/image5b.png){width="5.90625in"
height="3.1770833333333335in"}
