# Timbre · guía de marca v1

## La idea
Timbre te avisa cuando aparece un alquiler que coincide con lo que buscás. Uruguay primero. La marca es cercana, clara y con carácter propio.

## Logo elegido
Puerta redonda con la t construida en sus paneles. El pulsador se convierte en el punto de la i. La firma completa es puerta + imbre: la inicial se escribe una sola vez. Para formatos cuadrados, usar el símbolo o el ícono. Los archivos de logo/ usan trazados vectoriales y no requieren instalar una fuente.

## Versiones y espacio
- Verde sobre fondos claros: horizontal y símbolo.
- Marfil sobre verde: versión inversa de marca.
- Negro y blanco: reproducción a una tinta.
- Reservar alrededor de la firma una distancia igual al lado del pulsador. Mantener proporciones y orientación.
- Firma completa: desde 120 px de ancho. Símbolo: desde 24 px. Para favicon de 16–32 px usar la versión óptica incluida, con huecos más amplios y sin el picaporte.
- No agregar otra t delante de la puerta ni escribir timbre completo junto al símbolo.

## Color de pantalla
Verde #173F36 (RGB 23,63,54). Marfil #F4F0E6 (244,240,230). Amarillo de acento #F2CA52 (242,202,82). Fondo #F3F5EC (243,245,236). Texto #17312A (23,49,42). Secundario #56645B (86,100,91).

El ícono elegido combina verde de fondo y marfil en el símbolo; contraste 10.25:1. El amarillo se usa como acento de la interfaz. Tokens CSS y JSON incluidos. Los valores están preparados para pantalla.

## Tipografía
Manrope Variable, SIL Open Font License 1.1. Títulos 32 px/650, subtítulos 20 px/650, cuerpo 16 px/450 e interlínea 1.5; datos secundarios 14 px/500 y controles 600. Precios con numerales tabulares. El logo conserva sus propias letras dibujadas; Manrope se usa en la interfaz y los textos.

## Voz: Con un guiño
Voseo natural: buscá, elegí, guardá, te avisamos. El timbre aparece en los avisos; la información de precio, ubicación y gastos sigue siendo concreta.

- Presentación: «Tu próximo lugar puede estar por sonar.»
- Aviso: «Sonó un timbre en Cordón.»
- Texto: «Apareció un alquiler que coincide con tu búsqueda: 1 dormitorio, $26.500 + $3.200 de gastos.»
- Sin novedades: «Todavía no sonó. Te avisamos cuando aparezca un alquiler que coincida con tu búsqueda.»
- Vencido: «Este aviso ya no está disponible. Mirá otros lugares de tu búsqueda.»
- Error: «No pudimos cargar los avisos. Probá de nuevo.»

Búsquedas son los filtros guardados; Timbres son los avisos de nuevos alquileres que coinciden. Avisos es la configuración de cómo recibirlos. Buscar, filtrar, guardar y contactar conservan su significado.

## Íconos y máscaras
El ícono estándar conserva el dibujo elegido y se entrega en cuadrado completo, sin esquinas transparentes. El sistema operativo aplica su máscara. La versión maskable incluye un margen mayor para adaptarse a recortes circulares. Usar el archivo maskable solo en el manifest con purpose: maskable. El favicon tiene una adaptación óptica para tamaños pequeños.

## Movimiento y sonido
Secuencia de 3300 ms: suena el timbre; puerta hacia afuera sobre la bisagra izquierda; el nombre sale del hueco; se cierra en el logo. Sin marco fijo. El final conserva la geometría del master. La demo incluye recorrido manual, sonido opcional desactivado por defecto y vista estática cuando se pide movimiento reducido. Se incluye el sonido de dos notas (880 y 660 Hz) como WAV opcional.

## Archivos
logo/: SVG y PNG del logo y el símbolo. iconos/: ícono de app y variante maskable. web/: favicons, apple-touch-icon, iconos PWA, manifest y cabecera HTML. tokens/: CSS y JSON. tipografia/: Manrope y licencia. voz/: textos es-UY. animacion/: demo HTML/CSS/JS sin dependencias externas. sonido/: WAV. guia/: esta guía.
