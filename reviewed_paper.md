Debo de trabajar rapido porque tengo 4 potenciales reviwed papers:

- TCOM paper actualmente avazando para la estimación en 3D mediante beamstearing.
- TCOM paper VALIDACION EXPERIMENTAL de la estimación 3D mediante mediciones experimentales en el testbed.
- Unión coperativa entre OWC y OWP, añadiendo la cobertura estudiada experimentalmente para aumentar la cobertura.
- Physics informed NN usado para calibrar el patron de irradicación del LED. La idea es entrenar un modelo que aprenda del datasheet y con pocas muestras calibrar el patron de irradicación del LED.
  Con este entrenamiento se tendria una aproximación más fidedigna que cualquier modelo. Este problema es generalizado y se puede usar para diferentes LEDs. Podemos probar con distintos LEDs y se vería su adaptabilidad. La idea es que en la literatura actual se emplea generalmente el modelo lambertiano, pero cuando se lleva a la prácica, muchos paper terminan aproximando el lambertiano a un polinomio [muchas citas]. Con este metodo se puede con pocas muestras tener un modelo que permita estimar la posicion. Notar que se puede comparar el PINN con el NN y Model-based, a fin de verse la diferencia en este aspecto.
