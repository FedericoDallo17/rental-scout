# Rental Scout — seguimiento personal y superficie en búsquedas

## Comportamiento

Cada tarjeta permitirá guardar o quitar un favorito y registrar por separado las fechas de contacto, visita y rechazo. Las fechas serán editables y se podrán borrar para corregir una marca. Marcar un rechazo no borrará los contactos ni las visitas anteriores. Los datos serán privados de cada usuario.

Una sección «Mis apartamentos» permitirá consultar todos los guardados o con seguimiento, con filtros por favoritos, contactados, visitados y rechazados. Estará disponible incluso sin búsquedas guardadas. No dependerá de que el apartamento siga coincidiendo con una búsqueda.

Al crear o editar una búsqueda se podrá indicar superficie mínima y máxima en m², junto al precio y dormitorios. El criterio se guardará y se aplicará tanto al listado como a las coincidencias que generan notificaciones. Los campos vacíos no limitarán la superficie; con límites activos se excluirán avisos sin superficie conocida. El filtro temporal actual del listado mantendrá su opción de incluir superficie desconocida.

## Implementación propuesta para aprobación

1. Nueva tabla `listing_tracks`: usuario, referencia opcional al aviso, identidad de origen, favorito, `contacted_on`, `visited_on`, `rejected_on`, y una copia de título, enlace, origen, ubicación, precio, gastos, dormitorios y superficie. Índice único por usuario y origen/identidad del aviso. La copia conservará el apartamento cuando la purga elimine el anuncio del inventario compartido; la referencia se pondrá en NULL.
2. Nuevas columnas opcionales `min_square_meters` y `max_square_meters` en `search_preferences`. Validación de enteros no negativos y mínimo menor o igual al máximo.
3. Acciones autenticadas con consultas limitadas al usuario actual. Carga de seguimientos por lote para las tarjetas. Formularios fuera del enlace al portal y etiquetas accesibles.
4. Filtro de superficie común para búsquedas guardadas, coincidencias y notificaciones. Mantener las búsquedas existentes sin restricciones nuevas.
5. Interfaz en español e inglés, usando los estilos actuales y conservando el espejo CSS exigido por el proyecto.

## Verificación

- Aislamiento entre usuarios y rechazo de modificaciones a seguimientos ajenos.
- Guardar, quitar favorito, editar fechas y mantener contacto/visita después de rechazar.
- Recuperar apartamentos en «Mis apartamentos» sin búsquedas ni coincidencias actuales.
- Conservar los datos personales y el enlace después de purgar el aviso original.
- Persistencia de superficie; límites inclusivos, valores inválidos, rango invertido y superficie desconocida.
- Coincidencias y notificaciones respetan la superficie de la búsqueda.
- Ejecutar la suite Rails y actualizar STATUS, especificación y plan; no ejecutar scrapes reales.

## Estado

Migraciones aprobadas por el usuario el 2026-10-08. Implementado en `feat/apartment-tracking` e integrado en `main` local (commit `7f9eae3`). La migración fue aplicada a las bases locales de pruebas y desarrollo. No se modificó producción.
