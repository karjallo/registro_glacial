## registro_glacial
# PostgreSQL — Guía de instalación, seguridad y carga de datos

## Índice

1. [Instalación y configuración inicial](#1-instalación-y-configuración-inicial)
2. [Gestión de usuarios y permisos](#2-gestión-de-usuarios-y-permisos)
3. [Seguridad del servidor](#3-seguridad-del-servidor)
4. [Carga de datos — staging vs core](#4-carga-de-datos--staging-vs-core)
5. [Consideraciones sobre los datos](#5-consideraciones-sobre-los-datos)

---

## 1. Instalación y configuración inicial

### Instalación (Arch Linux)

```bash
sudo pacman -S postgresql
```

Al instalar, `pacman` crea automáticamente el usuario de sistema `postgres` y la ruta `/var/lib/postgres/data` con los permisos correctos.

### Inicializar el cluster

```bash
sudo -u postgres initdb -D /var/lib/postgres/data
```

`sudo -u postgres` ejecuta el comando como el usuario `postgres`, que debe ser el dueño del servicio.

### Gestionar el daemon con systemd

```bash
# Iniciar el servicio
sudo systemctl start postgresql

# Verificar el estado
sudo systemctl status postgresql

# Arrancar automáticamente al iniciar el sistema
sudo systemctl enable postgresql
```

> **Nota:** En sistemas que no usan systemd, se puede usar `pg_ctl`, especialmente útil si PostgreSQL fue compilado desde código fuente. Permite especificar `-l logfile` para definir la ubicación del log.

### Ingresar a la base de datos

```bash
sudo -u postgres psql
```

---

## 2. Gestión de usuarios y permisos

Operar todo con el usuario `postgres` (superusuario) es mala práctica. Se recomienda crear usuarios con permisos acotados según su rol:

| Usuario | Rol | Permisos sugeridos |
|---|---|---|
| `pinguino-owner` | Migraciones y DDL | `CREATE`, `ALTER`, `DROP` |
| `pinguino-app` | Backend / API | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |
| `pinguino-analista` | Análisis y consultas | `SELECT` |

Se recomienda **un usuario por cada servicio o API** que acceda a la base. Así, si una credencial o máquina es comprometida, el impacto queda aislado.

### Rotación de credenciales

Es posible configurar rotación automática de contraseñas cada cierto período de tiempo para reducir el riesgo ante filtraciones.

### Configuración de autenticación — `pg_hba.conf`

El archivo `pg_hba.conf` (ubicado en `/var/lib/postgres/data/pg_hba.conf`) controla qué usuarios pueden conectarse, desde qué dirección IP y con qué método de autenticación.

```
# TYPE  DATABASE  USER              ADDRESS       METHOD
local   all       pinguino-app                    scram-sha-256
host    all       pinguino-analista 192.168.1.0/24 scram-sha-256
```

Declarar usuarios con sus IPs permitidas evita conexiones directas al servidor desde IPs ajenas. Sin embargo, **esto no protege contra SQL injection**, ya que ese vector de ataque proviene del propio backend.

---

## 3. Seguridad del servidor

### Prevención de SQL Injection

El backend o API que construye las queries **nunca debe concatenar strings** para armar las consultas. Siempre usar **queries parametrizadas**:

```python
# ❌ Vulnerable
query = f"SELECT * FROM customers WHERE email = '{email}'"

# ✅ Seguro
query = "SELECT * FROM customers WHERE email = %s"
cursor.execute(query, (email,))
```

### Logging de actividad

En `postgresql.conf` se puede habilitar el registro de todas las queries para detectar anomalías:

```conf
# postgresql.conf
log_connections = on
log_disconnections = on
log_statement = 'all'
log_min_duration_statement = 0
```

Analizando estos logs se pueden detectar señales de compromiso:
- `SELECT` que devuelve 10.000 filas cuando normalmente devuelve 10
- Conexiones desde IPs desconocidas
- Actividad en horarios inusuales

### Envío de logs a servidor externo

Si un atacante obtiene suficiente acceso, puede eliminar los logs locales. Para mayor seguridad, enviar los logs a un servicio externo:

| Opción | Tipo | Notas |
|---|---|---|
| Grafana Loki | Open source, self-hosted | Puede correr dockerizado de forma local |
| Datadog | SaaS | |
| AWS CloudWatch | SaaS | |

Dockerizar Grafana Loki junto al servidor PostgreSQL mejora el aislamiento y evita costos adicionales.

---

## 4. Carga de datos — staging vs core

### ¿Por qué usar un schema staging?

PostgreSQL, ante cualquier error en una transacción, no carga nada (rollback total). Para evitar perder toda la carga por datos sucios, se usa un schema `staging` que acepta todo como `TEXT` sin validaciones.

El flujo es:

```
CSV → staging (todo como TEXT, sin constraints)
              ↓
           transform + validación
              ↓
         core (tipos correctos, constraints, FKs)
```

- **Extract + Load** → `staging-etl.sql` (lee el CSV, carga sin transformar)
- **Transform** → `core-etl.sql` (castea, limpia, filtra y migra a core)

### `COPY` vs `\copy`

| | `COPY` | `\copy` |
|---|---|---|
| Lo ejecuta | El servidor PostgreSQL (usuario `postgres`) | El cliente `psql` (usuario del sistema) |
| Permisos necesarios | El proceso `postgres` debe poder leer el archivo | Los permisos del usuario que ejecuta `psql` |
| Uso recomendado | Producción | Desarrollo |

`\copy` no es SQL estándar, por lo que no puede estar dentro de un bloque `BEGIN`/`COMMIT`.

### Ubicación segura de archivos CSV para `COPY`

Ni `/home/usuario` ni dentro de `/var/lib/postgres/data` son buenas opciones. La solución es una carpeta neutral:

```bash
sudo mkdir -p /var/local/db_imports/data/
sudo chown -R $(whoami):postgres /var/local/db_imports/
sudo chmod 750 /var/local/db_imports/
sudo chmod 750 /var/local/db_imports/data/
sudo cp ~/projects/registro_glacial/data/*.csv /var/local/db_imports/data/
sudo chmod 640 /var/local/db_imports/data/*.csv
```

Esto da acceso al grupo `postgres` sin exponer el home del usuario ni el directorio de datos del cluster.

### Transacciones y ACID

Los bloques `BEGIN` / `COMMIT` delimitan una transacción. Si algo falla en el medio, se puede hacer `ROLLBACK` y la base queda exactamente igual a como estaba antes.

Las transacciones garantizan cuatro propiedades (**ACID**):

| Propiedad | Descripción | Dónde se ve en el proyecto |
|---|---|---|
| **Atomicity** | Todo o nada — si falla un INSERT, se revierten todos los anteriores | `BEGIN` / `COMMIT` en los ETLs |
| **Consistency** | La base pasa de un estado válido a otro estado válido | `CHECK`, `FK`, `UNIQUE`, `NOT NULL`, ENUMs |
| **Isolation** | Las transacciones no se ven entre sí mientras se ejecutan | Gestionado internamente por PostgreSQL |
| **Durability** | Una vez commiteado, el dato sobrevive a cualquier falla del sistema | Gestionado internamente por PostgreSQL |

---

## 5. Consideraciones sobre los datos


### unit_price en order_items

Tras verificar los datos, el campo `unit_price` en `order_items` no corresponde al precio de lista del producto, sino al **precio ya descontado**. Esto se puede comprobar:

```sql
-- Si esta query no devuelve filas, la hipótesis es correcta
SELECT o.order_item_id, o.product_id, p.unit_price,
    o.discount_rate, o.unit_price
FROM core.order_items o
JOIN core.products p ON p.product_id = o.product_id
WHERE ABS(o.unit_price - (p.unit_price * (1 - o.discount_rate))) > 0.01;
```

### Filtros referenciales en la carga a core

Para evitar violaciones de FK que hagan rollback de toda la transacción, cada tabla dependiente filtra solo los registros cuyos padres cargaron exitosamente:

```sql
-- Solo order_items cuya orden existe en core
WHERE CAST(order_id AS INT) IN (SELECT id FROM core.orders)

-- Solo órdenes cuyo cliente existe en core
WHERE CAST(customer_id AS INT) IN (SELECT id FROM core.customers)
```
