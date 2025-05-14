% Programa de experimentos en 2D
Este proyecto se ha desarrollado para hacer un estudio en 2D del análisis del método
de modulación de orientación. Se configuran los parámetros de la sala en un archivo
y se puede obtener el gráfico de estimación de posicion vs. posicion real y el calculo
del rmse de la estimación para un determinado ser de n orientaciones.

Hiperparametros:
n: numero de orientacion (modificar en /optimization/gaOptimizer o gaOptimizerIteration)
N0 : nivel de ruido (modificar en /parameters/setupParameters.m)
WLS o LS: se modifica en positionEstimator.m para especificar el método a emplear

%% Paquetes de wireless:

+opticalWireless: Modelo de canal óptico.
+positionEstimators: Estimador de posicion principal e internamente los diferentes estiamdores n=3, n>3 (LS o WLS).
+visualization: Visualizamos el resultado y los vectores.

%% Carpeta experiment: 
Carpeta del experimento principal

/figures:
Generacion de figuras para el paper.
(Idea: Seria interesante correr el código para otra sala y ver como afecta en los vectores óptimos
y asi proponer una dependencia de los vectores óptimos con las dimensioens del ROOM)

/optimizacion:
Uso principalmente esto para el experimento
gaMonitor: funcion que genera la visualzacion por "generacion" del algoritmo genetico
gaOptimizer: función para el algoritmo genético considerando un valor de n
gaOptimizerIteration: acepta un arreglo de n (si se quiere evaluar más de un n a la ves)

/parameters:
parámetros del experimento

/results
Resultados de los experimentos realizados

/utils
positionEstimator: 
Hace el calculo de la simulación, genera el mapa de puntos reales basado en
el modelo y luego estima la posición de acuerdo a un método.
rmseCalculator: 
Funcion para la optimización, retorna el RMS para 
una cantidad de orientacioens n determinadas considerando los parámetros.

/main.m:
Test para un determinado set de orientaciones. Útil para probar los resultados de la iteraciones con GA
o para probar un grupo de orientacioens determinadas expresadas en coordenadas polares
como [theta,phi,...].
