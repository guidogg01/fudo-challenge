# Decisiones de diseño

Registro de las decisiones del proyecto, en formato ADR liviano: **Contexto → Decisión → Alternativas consideradas → Consecuencias**. El *qué* está en el README y en `docs/openapi.yaml`; acá va el **por qué**.

## Índice

**Plataforma**
1. Rack puro con un router propio
2. Puma como servidor
3. PostgreSQL con Sequel
4. Sidekiq y Redis como sistema de colas
5. Todo en Docker Compose
6. Configuración por variables de entorno

**Autenticación**
7. Contraseñas con bcrypt
8. Tokens opacos con hash SHA-256 en lugar de JWT
9. La autenticación la decide el router
10. Login sin pistas sobre qué usuarios existen

**Productos y creación asíncrona**
11. Creación asíncrona con `product_requests` y `perform_in(5)`
12. "5 segundos" significa "no antes de 5 segundos"
13. Job idempotente con `SELECT ... FOR UPDATE`
14. Reintentos acotados y fallo definitivo
15. Duplicados en vuelo: el 409 temprano solo mira productos creados
16. Nombre único sin distinguir mayúsculas con `lower(name)` y no `citext`
17. Datos pedidos en `jsonb`
18. Dinero como entero en centavos
19. Constraints en la base como segunda línea de defensa

**API**
20. Formato único de respuestas y errores
21. Mensajes en español, códigos en inglés
22. 404 en lugar de 403 para recursos ajenos
23. Paginación por offset; parámetros inválidos dan 422
24. `Content-Type: application/json` obligatorio (415)
25. `GET /products/{id}`
26. AUTHORS con `Rack::Files`, `Cache-Control` y `Last-Modified`
27. `/health` chequea la base y Redis
28. Gzip con `Rack::Deflater`

**Observabilidad**
29. Logs JSON por stdout y `X-Request-Id`

**Fallas**
30. Qué pasa si algo se muere a mitad de camino

**Entrada**
31. Límites y saneamiento del input

---

## 1. Rack puro con un router propio

**Contexto.** El enunciado prohíbe frameworks web como Rails o Sinatra.

**Decisión.** La app es un objeto Rack (`call(env)` → `[status, headers, body]`) con una cadena de middlewares y un router escrito a mano: una tabla de rutas (método + patrón) que llama a un handler por recurso.

**Alternativas consideradas.** Roda, Hanami o Grape: son frameworks web más chicos y violan el espíritu del enunciado. `Rack::Builder#map` sirve para prefijos, pero no maneja métodos ni parámetros como `:id`.

**Consecuencias.** Hay que resolver a mano el 404, el 405 con `Allow` y la extracción de parámetros de la ruta. Son pocas líneas, y es justo lo que el challenge quiere ver. `HEAD` se atiende como `GET` sin body (`Rack::Head`), así los monitores y cachés que usan HEAD no reciben un 405.

## 2. Puma como servidor

**Contexto.** Hace falta un servidor HTTP que hable Rack.

**Decisión.** Puma: multi-thread, el estándar de facto en Ruby (es el servidor por defecto de Rails).

**Alternativas consideradas.** Unicorn (un proceso por request, sin threads: más memoria, y no aprovecha la espera de I/O), Falcon (basado en fibers, menos conocido).

**Consecuencias.** Con threads, el código tiene que ser thread-safe: nada de estado global mutable y un pool de conexiones a la base (Sequel ya trae uno).

## 3. PostgreSQL con Sequel

**Contexto.** Hace falta persistencia con transacciones reales, índices únicos y constraints. Fudo usa PostgreSQL.

**Decisión.** PostgreSQL con **Sequel** como ORM liviano y sus migraciones.

**Alternativas consideradas.** ActiveRecord fuera de Rails (posible, pero arrastra mucho de Rails); SQL a mano con la gema `pg` (más código repetitivo y más riesgo de SQL injection).

**Consecuencias.** Las consultas son parametrizadas por defecto. Sequel expone las violaciones de constraints como excepciones específicas (`Sequel::UniqueConstraintViolation`), que usamos en el job.

## 4. Sidekiq y Redis como sistema de colas

**Contexto.** El enunciado exige que el procesamiento asíncrono corra en un sistema de colas de trabajos.

**Decisión.** Sidekiq con Redis, en un proceso `worker` separado de la app.

**Alternativas consideradas.** RabbitMQ, SQS o Kafka (más infraestructura, sin ventaja para este caso). Una cola sobre PostgreSQL, como GoodJob o Que (menos piezas, pero menos estándar en el ecosistema Ruby sin Rails).

**Consecuencias.** Sidekiq entrega cada job **al menos una vez**: un job puede ejecutarse dos veces, así que tiene que ser idempotente (decisión 13). Redis es una pieza más que operar.

## 5. Todo en Docker Compose

**Contexto.** El evaluador tiene que poder levantar todo sin instalar Ruby, PostgreSQL ni Redis. En Windows, además, las gemas nativas (`pg`, `bcrypt`) suelen dar problemas.

**Decisión.** Cinco servicios: `app`, `worker`, `db` (expuesto en el puerto 5433 del host), `redis` y `swagger-ui`. Usan healthchecks y `depends_on: condition: service_healthy`.

**Alternativas consideradas.** Instalación local documentada (frágil y distinta en cada sistema operativo).

**Consecuencias.** El único requisito es Docker. Los comandos de Ruby se corren con `docker compose run --rm app ...`.

## 6. Configuración por variables de entorno

**Contexto.** No puede haber secretos en el código, y cada entorno (desarrollo, test, producción) necesita valores distintos.

**Decisión.** Toda la configuración sale de variables de entorno, con un `.env.example` documentado y una base separada para tests.

**Alternativas consideradas.** Archivos YAML por entorno (más archivos, y es fácil terminar commiteando secretos).

**Consecuencias.** Sigue el estándar de "twelve-factor app" y funciona igual en Docker, en CI y en la nube.

## 7. Contraseñas con bcrypt

**Contexto.** Las contraseñas las eligen personas: son cortas y predecibles.

**Decisión.** bcrypt, con costo configurable (`BCRYPT_COST`, 12 por defecto; más bajo en tests).

**Alternativas consideradas.** SHA-256 con salt: es rápido, y por eso una GPU prueba miles de millones de contraseñas por segundo si se filtra la base. Argon2: más moderno, pero menos estándar en Ruby y con más parámetros que explicar.

**Consecuencias.** Verificar una contraseña tarda decenas de milisegundos a propósito. Es aceptable en el login, que es poco frecuente. bcrypt usa solo los primeros 72 bytes de la contraseña y el resto se ignora en silencio (verificado en bcrypt 3.1.22). Con contraseñas elegidas por personas no es un problema real, pero queda anotado.

## 8. Tokens opacos con hash SHA-256 en lugar de JWT

**Contexto.** Hace falta identificar al usuario en cada request. En pagos, poder cortar el acceso al instante importa más que ahorrarse una consulta.

**Decisión.** Un token aleatorio de 32 bytes (`SecureRandom`) que se muestra una sola vez. En la base se guarda solo su SHA-256 (`token_digest`), con `expires_at` (24 h, configurable) y `revoked_at`.

**Alternativas consideradas.**
- **JWT:** no necesita consultar la base, pero no se puede revocar antes de que venza sin agregar una lista negra, que es justamente una consulta a la base.
- **Guardar el token en claro:** si se filtra la base, todos los tokens quedan usables.

**Consecuencias.** Hay dos consultas por request autenticado, las dos por índice y muy baratas: el token, por su `token_digest` único, y después su usuario, por clave primaria. Se podrían unir en una sola con un join, pero no vale la complejidad para este volumen. SHA-256 alcanza porque el token tiene 256 bits al azar: no se puede adivinar por fuerza bruta, a diferencia de una contraseña. Los tokens vencidos o revocados no se borran. Esa limpieza, igual que la renovación con refresh tokens, queda fuera del alcance: en un sistema real la resolvería un servicio de autenticación dedicado. Si la autenticación pasara a ese servicio, lo natural sería un JWT de vida corta firmado por él, con el vencimiento embebido, más un refresh token; esta API solo verificaría la firma, y la revocación inmediata pasaría a depender de la vida corta del token o de una lista de revocados. `AuthToken.find_active` compara `expires_at` con `Time.now` de Ruby, no con `NOW()` de PostgreSQL. Como los dos lados están en UTC, la única diferencia posible es el desfase entre los relojes de los contenedores de la app y de la base, que en la práctica es de milisegundos.

## 9. La autenticación la decide el router

**Contexto.** Casi todas las rutas son privadas, salvo login, AUTHORS y health.

**Decisión.** Cada ruta de la tabla del router dice si es pública. Para las privadas, el router valida el token antes de llamar al handler y le pasa el usuario actual.

**Alternativas consideradas.** Un middleware de autenticación con una lista de rutas públicas: duplica el conocimiento de las rutas en dos lugares.

**Consecuencias.** Es imposible agregar una ruta sin decidir explícitamente si es pública. Los 401 no llevan el header `WWW-Authenticate: Bearer` que recomienda el RFC 6750: el contrato no lo usa y el cliente distingue los casos por `error.code`.

## 10. Login sin pistas sobre qué usuarios existen

**Contexto.** Un atacante podría usar el login para descubrir usuarios válidos.

**Decisión.** El mismo 401 (`invalid_credentials`) y el mismo mensaje exista o no el usuario. Si el usuario no existe, igual se compara contra un hash bcrypt fijo, para que la respuesta tarde lo mismo.

**Alternativas consideradas.** Mensajes distintos ("usuario inexistente", "contraseña incorrecta"): más cómodos, pero filtran información.

**Consecuencias.** El cliente no sabe cuál de los dos datos está mal, y es intencional. El usuario se guarda en claro, porque hay que buscarlo; lo protegen el acceso a la base y que nunca se revele en las respuestas.

## 11. Creación asíncrona con `product_requests` y `perform_in(5)`

**Contexto.** El enunciado pide que la respuesta no confirme la existencia del producto y que el producto aparezca 5 segundos después, usando una cola.

**Decisión.** `POST /products` valida, guarda una **solicitud** (`product_requests`, id UUID, estado `pending`), encola `CreateProductJob.perform_in(5, request_id)` y responde **202 Accepted** con `Location: /product_requests/{id}`. Nunca se usa `sleep`.

**Alternativas consideradas.**
- Insertar el producto con un flag `visible_at` y sin job: no cumple con "correr en una cola de trabajos".
- Encolar sin guardar la solicitud: el cliente no tendría cómo saber si la creación falló.

**Consecuencias.** El cliente consulta el estado en `GET /product_requests/{id}`. Queda un registro auditable de cada pedido y de su resultado.

## 12. "5 segundos" significa "no antes de 5 segundos"

**Contexto.** Sidekiq no ejecuta los jobs programados al segundo exacto: un hilo revisa la lista de programados cada cierto intervalo. Verificado en el código de Sidekiq 8.1.7: el intervalo es `average_scheduled_poll_interval` (5 s por defecto) y, con menos de 10 procesos, cada espera es al azar entre 0,5× y 1,5× ese valor.

**Decisión.** `perform_in(5)` y `average_scheduled_poll_interval = 1`. El producto aparece entre 5 y unos 6,5 segundos después, nunca antes.

**Alternativas consideradas.** Dejar el valor por defecto (el producto podría tardar hasta unos 12,5 s). `sleep(5)` dentro del job (ocupa un thread del worker sin hacer nada y no escala).

**Consecuencias.** Una consulta liviana a Redis por segundo. Queda documentado en el README que la demora es aproximada. Justo después de reiniciar el worker, Sidekiq espera entre 10 y 15 segundos antes de su primera revisión de jobs programados (`initial_wait` de `Sidekiq::Scheduled::Poller`, verificado en 8.1.7), así que el primer producto después de un reinicio puede tardar unos 10 segundos.

## 13. Job idempotente con `SELECT ... FOR UPDATE`

**Contexto.** Sidekiq puede ejecutar el mismo job más de una vez, incluso en paralelo (por ejemplo, si un worker se reinicia en el medio).

**Decisión.** En una sola transacción: bloquear la fila de la solicitud con `SELECT ... FOR UPDATE`, salir sin hacer nada si ya no está `pending`, insertar el producto y marcar la solicitud `completed`.

**Alternativas consideradas.**
- Chequear `pending` sin lock: dos ejecuciones simultáneas verían `pending`. La segunda chocaría contra el índice único con el producto que creó la primera y marcaría como fallida una solicitud que en realidad se completó.
- Locking optimista (columna `lock_version`): sirve, pero agrega una columna y un reintento manual para un caso que el lock de fila resuelve directamente.

**Consecuencias.** Correr el job N veces tiene el mismo efecto que correrlo una vez. El lock dura solo lo que tarda la transacción.

## 14. Reintentos acotados y fallo definitivo

**Contexto.** Un error inesperado (la base se cae un momento) no debería perder la solicitud ni dejarla `pending` para siempre.

**Decisión.** El job deja que Sidekiq reintente (`retry: 5`, con espera creciente). Al agotarse, `sidekiq_retries_exhausted` marca la solicitud `failed` con `creation_failed` y loguea el error. Un nombre repetido **no** se reintenta: es un fallo de negocio, se marca `failed` con `name_already_taken` en el momento.

**Alternativas consideradas.** Los 25 reintentos por defecto de Sidekiq (unos 21 días: demasiado para una creación que el usuario espera ver en segundos). Sin reintentos (un error transitorio haría fallar la creación).

**Consecuencias.** Toda solicitud termina en `completed` o en `failed` (con el mensaje "No se pudo crear el producto."), en unos pocos minutos como máximo. La excepción: si la base está caída durante todos los reintentos (unos 7 a 9 minutos), tampoco se la puede marcar `failed`, y la solicitud queda `pending` hasta que el worker se reinicie y la vuelva a encolar (decisión 30).

## 15. Duplicados en vuelo: el 409 temprano solo mira productos creados

**Contexto.** Como la creación es asíncrona, pueden llegar dos pedidos con el mismo nombre antes de que el primero se procese. El PDF no dice cómo responder en ese caso.

**Decisión.** `POST /products` hace un chequeo temprano solo contra los productos ya creados y, si encuentra uno con el mismo nombre, responde 409. Si llegan dos pedidos seguidos con el mismo nombre, los dos reciben 202. En el job, el índice único de la base deja pasar a uno solo y el otro queda en `failed` con `name_already_taken`.

**Alternativas consideradas.** Que el chequeo temprano también mire las solicitudes en `pending`. Da feedback antes en un caso poco común, pero agrega lógica y no cambia la garantía: igual hace falta el índice único, porque dos requests simultáneos pueden pasar el chequeo a la vez (condición de carrera).

**Consecuencias.** El requisito se cumple siempre, porque lo garantiza la base. El chequeo temprano es una ayuda de usabilidad, no la garantía.

*(Confirmada por Guido el 2026-10-19.)*

## 16. Nombre único sin distinguir mayúsculas con `lower(name)` y no `citext`

**Contexto.** "Mesa" y "mesa" tienen que contar como el mismo producto del mismo usuario (y lo mismo para los nombres de usuario).

**Decisión.** El nombre se normaliza (se recortan los extremos y se colapsan los espacios repetidos) y se guarda respetando las mayúsculas. La unicidad la da un índice único sobre la expresión `(user_id, lower(name))`.

**Alternativas consideradas.** El tipo `citext`: requiere instalar una extensión de PostgreSQL y hace que *todas* las comparaciones de la columna ignoren mayúsculas, lo que es menos explícito.

**Consecuencias.** Las consultas de duplicados tienen que usar `lower(name)` para aprovechar el índice. El mismo índice sirve para filtrar los productos por `user_id`. La `description` no se normaliza: se guarda tal como llega (puede tener espacios repetidos o en los bordes, o ser una cadena vacía), porque no participa de ninguna regla de unicidad. Solo el `name` se recorta y colapsa sus espacios.

## 17. Datos pedidos en `jsonb`

**Contexto.** La solicitud tiene que guardar lo que pidió el usuario hasta que el job lo procese.

**Decisión.** Una columna `payload jsonb` con los datos ya validados y normalizados.

**Alternativas consideradas.** Repetir las columnas de `products` en `product_requests`: duplica el esquema y obliga a migrar dos tablas por cada campo nuevo.

**Consecuencias.** El tipado fuerte vive en `products`, que es donde importa. Si el payload tuviera algo inválido, los constraints de `products` lo rechazan igual.

## 18. Dinero como entero en centavos

**Contexto.** Los floats no representan exactamente valores como 0,1: `0.1 + 0.2 != 0.3`. En pagos, eso termina en diferencias de centavos.

**Decisión.** `price_cents` es un entero (`bigint`), en la base y en la API, como hace Stripe. Un número con decimales o un string → 422.

**Alternativas consideradas.** `numeric(12,2)` en la base con `BigDecimal` en Ruby: es exacto, pero en JSON viaja como string o como float y obliga al cliente a manejar decimales.

**Consecuencias.** El cliente divide por 100 para mostrar. La moneda no se modela: se asume una sola, y modelarla queda como próximo paso.

## 19. Constraints en la base como segunda línea de defensa

**Contexto.** La app valida el input, pero un bug, un script o una consola pueden saltearse la validación.

**Decisión.** `NOT NULL`, `CHECK` de longitudes y de valores no negativos, `CHECK` de estados válidos y `CHECK` de que "completed" y "tiene producto" van juntos, y de que "failed" y "tiene `error_code`" también.

**Alternativas consideradas.** Validar solo en la app (más simple, pero la integridad depende de que nadie se equivoque nunca).

**Consecuencias.** La base nunca guarda datos inválidos. Las validaciones de la app siguen existiendo para devolver errores claros por campo.

## 20. Formato único de respuestas y errores

**Contexto.** Un cliente necesita respuestas predecibles. El código no debería armar respuestas de error a mano en cada lugar.

**Decisión.** Éxito: `{ "data": ... }` (más `meta` en las listas). Error: `{ "error": { "code", "message", "details" } }`. Hay una jerarquía chica de excepciones (`ApiError` y subclases) y **un único middleware** que las traduce a HTTP. Un error inesperado da 500 con `internal_error`, sin stack trace hacia el cliente (el detalle va al log).

**Alternativas consideradas.** JSON:API o RFC 9457 (Problem Details): son estándares completos, pero más pesados de lo que este challenge necesita.

**Consecuencias.** Agregar un error nuevo es agregar una subclase. El cliente siempre puede leer `error.code`.

## 21. Mensajes en español, códigos en inglés

**Contexto.** Guido quiere que lo que se ve en las respuestas esté en español.

**Decisión.** Los `message` van en español. Los `code` (`validation_failed`, `name_already_taken`, ...) son identificadores fijos en inglés, igual que el resto del código.

**Alternativas consideradas.** Todo en inglés (más común en APIs públicas). Mensajes traducibles según `Accept-Language` (sobre-ingeniería para este caso).

**Consecuencias.** El cliente programa contra `code`, que nunca cambia. El texto puede cambiar sin romper a nadie.

*(Decidida por Guido el 2026-10-19.)*

## 22. 404 en lugar de 403 para recursos ajenos

**Contexto.** Si un usuario pide el producto o la solicitud de otro, un 403 confirmaría que ese id existe.

**Decisión.** 404, exactamente igual que si no existiera. Las consultas siempre filtran por `user_id`.

**Alternativas consideradas.** 403 (más "semántico", pero filtra información).

**Consecuencias.** No se puede enumerar recursos ajenos. Los UUID de las solicitudes, además, no se pueden adivinar.

## 23. Paginación por offset; parámetros inválidos dan 422

**Contexto.** Un usuario puede tener muchos productos.

**Decisión.** `?page=1&per_page=20`: 20 por defecto, máximo 100, orden estable por `id`, y `meta` con `page`, `per_page`, `total` y `total_pages`. Valores inválidos (no enteros, menores a 1, `per_page > 100`) → 422 con el detalle. Una página fuera de rango → 200 con `data: []`.

**Alternativas consideradas.**
- Normalizar en silencio (por ejemplo, `per_page=500` → 100): el cliente no se entera de que pidió algo imposible.
- Paginación por cursor (`?after=42`): más eficiente con tablas enormes y estable ante inserciones, pero más compleja de explicar y de usar. Queda como próximo paso.

**Consecuencias.** `OFFSET` grandes son lentos en tablas muy grandes, y el `COUNT(*)` cuesta una consulta extra. Es aceptable para este volumen. Un query string que ni siquiera se puede leer (`?page=%`, `?page=%FF`) es otra cosa: 400 `invalid_query`, porque no hay un campo concreto que señalar en el detalle.

## 24. `Content-Type: application/json` obligatorio (415)

**Contexto.** Los endpoints que reciben un body esperan JSON.

**Decisión.** Si `POST /auth/login` o `POST /products` llegan sin `Content-Type: application/json` → 415. Un JSON mal formado → 400.

**Alternativas consideradas.** Intentar parsear cualquier cosa (errores más confusos para el cliente).

**Consecuencias.** Los errores del cliente se distinguen bien: 415 (formato equivocado), 400 (JSON roto) y 422 (JSON correcto con datos inválidos). Además, el body tiene un tope de 16 KB (decisión 31).

## 25. `GET /products/{id}`

**Contexto.** El PDF pide un solo endpoint de consulta. Pero cuando una solicitud termina en `completed`, la respuesta informa el producto creado.

**Decisión.** Además de la lista, `GET /products/{id}`, que es el destino de `product_url` en la solicitud completada.

**Alternativas consideradas.** Solo la lista: para ver el producto recién creado, el cliente tendría que recorrer páginas buscando el id.

**Consecuencias.** Es la convención REST de colección y elemento, y reusa el mismo filtro por usuario. Cuesta pocas líneas.

*(Confirmada por Guido el 2026-10-19.)*

## 26. AUTHORS con `Rack::Files`, `Cache-Control` y `Last-Modified`

**Contexto.** Hay que servir un archivo estático indicando que se puede cachear 24 horas.

**Decisión.** `Rack::Files` (incluido en Rack) sirve `public/AUTHORS` como `text/plain` con `Cache-Control: public, max-age=86400`. Es público, coherente con `public`. `Rack::Files` agrega `Last-Modified` y responde 304 ante un `If-Modified-Since` con esa fecha (verificado en Rack 3.2.7).

**Alternativas consideradas.** Agregar `ETag`: para un archivo de 12 bytes, revalidar no ahorra nada que valga la pena, y `max-age` ya evita los requests durante 24 horas. Leer el archivo a mano: reinventa lo que Rack ya trae.

**Consecuencias.** Cero código propio para servir el archivo. El caché del navegador o de un proxy no vuelve a pedirlo durante 24 horas.

## 27. `/health` chequea la base y Redis

**Contexto.** Docker Compose (y cualquier orquestador) necesita saber si la app está lista para atender.

**Decisión.** `GET /health` hace `SELECT 1` en PostgreSQL y `PING` en Redis. Si ambos responden → 200; si alguno falla → 503, con el detalle de cuál.

**Alternativas consideradas.** Solo "estoy vivo" (no detecta que la app no puede trabajar). Separar *liveness* y *readiness* (lo correcto en Kubernetes, pero de más para este challenge: queda como próximo paso).

**Consecuencias.** Si la base se cae, `/health` da 503. En un orquestador habría que cuidar que eso no reinicie la app en loop: por eso, en producción, se separaría en dos endpoints. Para que una base que deja de responder no cuelgue los requests, la conexión usa `connect_timeout` de 2 segundos para las conexiones nuevas y `tcp_user_timeout` de 2 segundos para las abiertas (verificado cortando la red de la base: el primer request pasó de colgarse más de 90 segundos a responder en 2,4). La resolución DNS no tiene timeout propio: si el nombre del host deja de existir, como pasa en Docker Compose al bajar el contenedor, cada intento puede tardar varios segundos más.

## 28. Gzip con `Rack::Deflater`

**Contexto.** Las respuestas tienen que ir comprimidas con gzip cuando el cliente lo pide.

**Decisión.** `Rack::Deflater`, que mira `Accept-Encoding` y comprime solo si el cliente lo acepta. Va afuera del manejo de errores, así que los errores también se comprimen.

**Alternativas consideradas.** Comprimir en un proxy (nginx): es lo habitual en producción, pero el enunciado pide que lo haga la API.

**Consecuencias.** Las respuestas comprimidas llevan `Content-Encoding: gzip` y `Vary: Accept-Encoding`, para que los cachés no mezclen versiones.

## 29. Logs JSON por stdout y `X-Request-Id`

**Contexto.** Payments necesita poder investigar qué pasó con un pedido puntual. Fudo usa OpenSearch, que ingiere logs estructurados.

**Decisión.** Una línea JSON por evento en stdout. Una línea por request (método, path, status, duración en ms, `request_id`, `user_id`). `X-Request-Id`: se respeta el que llega o se genera uno, se devuelve y se pasa al job, para correlacionar el request con su procesamiento. Eventos del job: `product_created` (info) y `product_creation_failed` (warn o error, con el motivo). Nunca se loguean contraseñas, tokens ni el header `Authorization`.

**Alternativas consideradas.** Logs en texto libre (difíciles de filtrar y agregar). Levantar OpenSearch, Kibana o Grafana (sobre-ingeniería para el challenge).

**Consecuencias.** Los logs están listos para enviarse a OpenSearch o Kibana sin transformarlos. Las métricas y el tracing (OpenTelemetry) quedan como próximo paso. El re-encolado al arrancar el worker (decisión 30) no conoce el `request_id` original, así que en ese caso el job loguea `request_id: null`. Los middlewares reciben el logger como parámetro para que los tests verifiquen sus logs; los handlers, el job y los servicios usan la constante `LOGGER`, que los tests reemplazan con `stub_const`.

## 30. Qué pasa si algo se muere a mitad de camino

**Contexto.** La app, el worker o Redis pueden caerse en cualquier momento. Una solicitud no puede quedar `pending` para siempre ni generar un producto duplicado o a medias.

**Decisión.**
- **App:** guardar la solicitud y encolar el job ocurren dentro de la misma transacción de PostgreSQL. Si algo falla en el medio, se deshace todo y el cliente recibe un error y puede reintentar.
- **Cliente que reintenta** porque no recibió el 202: no se duplica nada, porque el índice único deja la segunda solicitud en `failed`.
- **Worker:** el job es una sola transacción, así que un crash nunca deja un producto a medias. En un apagado normal, Sidekiq devuelve a la cola los jobs en curso.
- **Redis:** persistencia en disco con `appendonly yes`.
- **Worker con crash brusco:** la versión gratuita de Sidekiq pierde el job en curso, porque lo saca de Redis al tomarlo (`BRPOP`, verificado en `lib/sidekiq/fetch.rb` de Sidekiq 8.1.7). Como red de seguridad, al arrancar el worker (`config.on(:startup)`) se re-encolan las solicitudes `pending` de más de 1 minuto. Es seguro porque el job es idempotente.

**Alternativas consideradas.**
- El patrón *transactional outbox* (guardar el "evento" en la base y que otro proceso lo publique en la cola): es la solución completa al problema de escribir en dos sistemas a la vez, pero suma un proceso más.
- Sidekiq Pro (`super_fetch`), que no pierde jobs ante un crash: es pago.
- Un chequeo periódico en vez de solo al arrancar: necesita un scheduler (por ejemplo `sidekiq-cron`), otra dependencia más.

**Consecuencias.** Ninguna solicitud queda `pending` para siempre mientras el worker se vuelva a levantar, y nunca hay productos duplicados ni a medias. Queda como próximo paso el chequeo periódico, el outbox y `Idempotency-Key`.

*(Confirmada por Guido el 2026-10-19.)*

## 31. Límites y saneamiento del input

**Contexto.** Ningún input del cliente debería terminar en un 500: un 500 dice "el servidor falló" y además ensucia los logs y las alertas. Y un endpoint público, como el login, no debería obligar al servidor a leer megas a memoria.

**Decisión.**
- El body JSON tiene un tope de 16 KB → 413 `payload_too_large`. Se leen como máximo 16 KB + 1 byte, así que un `Content-Length` que miente no lo saltea.
- Un body que no es UTF-8 válido, o que tiene el carácter nulo (`\u0000`, que el `text` de PostgreSQL no acepta) → 400 `invalid_json`.
- Un query string mal formado (`?page=%`, `?page[]=1&page[x]=2`) o con bytes que no son UTF-8 (`?page=%FF`) → 400 `invalid_query`.
- Un id de ruta que no puede existir (`/products/abc`, un número que no entra en un `bigint`, un UUID mal formado) → 404 sin consultar la base.
- Números de `price_cents` y `quantity` más grandes que sus columnas → 422 `out_of_range`.

**Alternativas consideradas.** Dejar que la base rechace estos casos: termina igual, pero con un 500 y un stack trace en el log por cada request inválido. Limitar el tamaño en Puma (`http_content_length_limit`): responde 413, pero con su propio formato y no con el de la API.

**Consecuencias.** Todo input del cliente termina en 400, 404, 413, 415 o 422 con el formato de error de siempre. Los 500 quedan solo para errores reales del servidor.

*(Surgida de las revisiones de código, 2026-10-19.)*
