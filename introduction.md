**Introduccion**

Introducción al sistemas de posicionameinto outdoor GNSS y sus limitaciones indoor.

Introducción a las soluciones Indoor basadas en RF (wifi, bluetooth, etc) y sus limitaciones en comparación con la solucion prometedora Optical Wireless Positioning. Introducción al Optical Wireless Positioning (en mi journal empleo IR-LED) además la relación con el término "Visible Light Positioning" (ampliamente empleado, cuando el LED es de luz visible). Razones por las que se usa el PD sobre cámaras como receptor. Princiaples técnicas RSS, AOA, TDOA, donde la más empleada es el RSS.

Estado del arte : Importancia de los modelos basados en física (model-based) vs. los modelos basado en Data-driven.

Estado del arte: Limitaciones con sistemas multi-LED (métodos empleados) que requiere de más de un transmisor (configuración tradicional de 4 transmisores). Uso de CRLB para la optimización de parámetros.

Ventajas de un Single LED VLP y Estado del arte de los sistemas Single LED VLP actuales.

Limitaciones para la estimación en 3D con un solo LED (en el estado del arte habitualmente enfocado en 2D).

En paralelo, Introducción a beamstearing optico y sus principales métodos.

introduccion al Optical Wireless Communication y su complementariedad al OWP y aplicación de beamstearing optico. El determinar la ubicación mediante OWP permitirá retorientar el LED mediante técnicas de beamstearing optico y eso incrementara el bitrate, SNR mediante la mejora del LOS.

Contribuciones:

- Nuevo método de estimación en 3D empleando un solo
  LED.
- Método de estimación que incluye el SNR en el
  calculo o estimación.
- Generalización de estimación para 2D y 3D empleando Single
  VLP para n orientaciones.
- Optimizacion de las orientacioens mediante algoritmo
  genético.
- CRLB (porque lo uso para explorar el limite teorico de algunos parametros en el paper)
- Algoritmo genetico (lo uso en el paper para optimización)
- En paralelo tecnicas de beamsteering que refuercen la factibilidad de la modulacion en el transmisor. Debe de dar soporte a lo que continua en el paper ya que se emula mecanicamente empleando un mecanismo gimbal que reorienta el Tx.
