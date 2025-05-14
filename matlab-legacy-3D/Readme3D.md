% Programa de experimentos en 3D
Es una rama generada a partir del proyecto 2D.

Se extienden las funciones para que sean generalizadas a 3D.

Hiperparametros:
n: numero de orientacion (modificar en /optimization/gaOptimizer o gaOptimizerIteration)
z: valores de altura que se estimarán (modificar en /parameters/setupParameters.m)
N0 : nivel de ruido (modificar en /parameters/setupParameters.m)
WLS o LS: se modifica en positionEstimator.m para especificar el método a emplear
(nota: por ahora solo hay WLS)

%% Proyecto
Todo lo que hay en 2D pero adicionalmente:

+positionEstimators: Se añaden métodos de posicionamiento en 3D.(Principales aportes y cambios !!)
+visualizacion: Se añade método de visualización en 3D.

/optimizacion:
No se ha modificado ni se ha probado (está igual copia y pega de 2D)

/parameters:
Se ha añadido el valor de z

/results
Resultados de los experimentos realizados

/utils
positionEstimator3D: Modificaicones para uso de 3 coordenadas
rmseCalculator3D: Modificaicones para uso de 3 coordenadas

/main.m y /main_WLS.m
Para probar especificamente con un set de n_orientaciones.

Nota: Esta quedando pendiente
- Revisar el valor de RMSE (90%), en algunas configuraciones se ve visualmente un 
error mayor pero el rmse figura pequeño. Verificar particularmente porque muchos valores
de SNR son -Inf y eso es interesante tomarlo en cuenta.
