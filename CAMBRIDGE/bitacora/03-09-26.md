# Research Project at Cambridge

A continuación resumo la idea del proyecto en el que trabajaré en Cambridge.

Objetivo: Estudio del posicionamiento en 3D para un sistema con Single-Anchor and Reorientable PD.

Consideremos un sistema de posicionamiento OWP que consta de un transmisor LED (visible or IR-LED) fijo en el techo; y un receptor basado en un PD montado en una superficie que puede rotar 360 e inclinar el PD. El sistema del testbed esta compuesto por un CNC de 3D que puede desplazar el PD en X,Y,Z y aparte una base rotatoria e de inclinación en el end-effector. La estructura tiene un LED en el centro.

Siguientes pasos:

1. Revisar el estado del arte.
2. Formular el problema (en particular porque cuando el drone se reorienta tambien podria desplazarse).
3. Preparar el avance para Iman (next week).
4. Escribir algunas simulaciones basadas en mi proyecto. En el mismo folder para que beba de esa idea.

Comentarios:

- Técnicamente es un problema simétrico que he estado trabajando ya en mi proyecto.
- Aplican todos los comentarios que me brindaron en el TCOM, GLOBECOM, etc.
- Objetivo: Submition al ICC (deatline: 02/10/26 extension: 30/10/26) En otras palabras: 2 meses. Se podria usar ML también.

Research Question:

Under what conditions can full 3D positioning be achieved using a single fixed optical anchor and a single actively reorientable photodiode through controlled receiver-orientation diversity?

- Observability : numero de orientaciones (number of minimum reorientation)
- Orientation design: eleccion de la orientación (genetic algoritmh or particle algorithm - limitacion de máximos degree of tilt ) —> usar la FIM.
- Estimation: Método para estimar en 3D. —> GLS es aun bueno ?
- Experimetnal performance. —> testear !!

Lectura: “ **Design and Performance Analysis for Indoor Visible Light Positioning With Single LED and Single-Tilted-Rotatable PD**”

Estimacion 2D : 1 LED/1 re-orientable PD. CRLB. Simple Selection of N (number of orientation) and “fixed inclination” osea solo se puede especificar la inclinacion pero no varia duarnte el experiemnto. A diferencia de mi metodo que puede usar con 2DOF cualquier (inclinacion, azimuth) —> Eleccion arquitectonica que tomar. 

Diferencias:

- Su analisis es en 2D —→ Nosotros 3D.
- [inclinacion] fija y no movible durante el experimento —→ Nosotros podemos variarla como DOF (drone).
- Metodo de estimación basado en iteraciones.(GWO-based positioning)
- Importante tomar en cuenta: Si se quiere hacer un tracking de objeto como el AZIMUTH es respecto a un sistema de coordenadas entonces si se monta sobre algo que CAMBIE ese sistema, por ejemplo GIRANDO entonces se debe conocer ese GIRO (indican: trabajo futuro)
- Requieren Calibracion (C1, C2) asi que mi método tambien lo requiere.
- Reportar que su version de curva con fitting se aproxima mejor que la LAMBERTIANA —> Denuevo un problema de patron lambertiano.
- Experimental : 50cm x 50cm x 30cm (un testbed muy pequeño). Algoritmo timepo : 9.7ms. APE de 0.91cm.

Lectura: “**Performance Comparison and Improvement for VLP With a Single LED and a Single Rotatable PD**”

Se compara dos metodos : uno de ellos del paper anterior y otro que es rotativo. El paper anterior gana. 

Comparacion en 2D. Teórico basado en el CRLB.

Segunda contribución: Se propone un método “adaptive-tilt-angle adjustment (ATAA)” si bien este consiste en ajustar los angulso de inclinacion del PD, esta se hace de manera adaptativa en cada posicion del testbed, es decir una arquitectura de dos pasos e iterativa. Haciendo que en la practica tengamos diferentes angulos. Cerca al centro : angulos mas grandes de inclinacion (ya que no limita tanto el FOV); mientras que cerca al borde : angulos mas pequeños de FOV.

Difernecia: Es en 2D, es teórico, adapta por posicion y no elije un SET OPTIMO.