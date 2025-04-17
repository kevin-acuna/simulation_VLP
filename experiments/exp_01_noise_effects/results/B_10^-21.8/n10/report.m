Single objective optimization:
20 Variables

Options:
CreationFcn:       @gacreationuniform
CrossoverFcn:      @crossoverscattered
SelectionFcn:      @selectionstochunif
MutationFcn:       @mutationadaptfeasible

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
    1              300         0.04278          0.2209        0
    2              450         0.04057          0.1307        0
    3              600         0.03823         0.08434        0
    4              750         0.03875         0.07235        1
    5              900         0.03756         0.06053        0
    6             1050         0.03467         0.05517        0
    7             1200         0.03364         0.05097        0
    8             1350         0.03449         0.04865        1
    9             1500         0.03293         0.04743        0
   10             1650         0.03222         0.04471        0
   11             1800         0.03195         0.04329        0
   12             1950          0.0303         0.04039        0
   13             2100         0.03084         0.03871        1
   14             2250          0.0312         0.03679        2
   15             2400          0.0293         0.03501        0
   16             2550         0.03065         0.03466        1
   17             2700         0.03114         0.03402        2
   18             2850         0.03028         0.03366        0
   19             3000         0.03001         0.03312        0
   20             3150         0.02916         0.03279        0
   21             3300          0.0293         0.03253        1
   22             3450          0.0299         0.03237        2
   23             3600         0.02997         0.03216        3
   24             3750         0.03027         0.03203        4
   25             3900         0.02875         0.03206        0
   26             4050         0.02991         0.03187        1
   27             4200          0.0295         0.03182        0
   28             4350          0.0294         0.03179        0
   29             4500         0.02969         0.03181        1
   30             4650         0.02993          0.0317        2

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
   31             4800         0.02957          0.0317        0
   32             4950         0.02933          0.0316        0
   33             5100         0.02922         0.03158        0
   34             5250         0.02903         0.03153        0
   35             5400         0.02941          0.0315        1
   36             5550         0.02948         0.03137        2
   37             5700         0.02927         0.03147        0
   38             5850         0.02926         0.03141        0
   39             6000         0.02892         0.03129        0
   40             6150         0.02906         0.03121        1
   41             6300          0.0291         0.03118        2
   42             6450          0.0291         0.03106        3
   43             6600          0.0286         0.03101        0
   44             6750         0.02893         0.03088        1
   45             6900         0.02874         0.03094        0
   46             7050         0.02824          0.0309        0
   47             7200         0.02829         0.03075        1
   48             7350         0.02815         0.03073        0
   49             7500          0.0287          0.0308        1
   50             7650         0.02876         0.03077        2
   51             7800         0.02907         0.03071        3
   52             7950         0.02865         0.03073        0
   53             8100         0.02856         0.03073        0
   54             8250         0.02853         0.03072        0
   55             8400         0.02889          0.0307        1
   56             8550         0.02887         0.03068        0
   57             8700         0.02876          0.0306        0
   58             8850         0.02853         0.03064        0
   59             9000         0.02869          0.0307        1
   60             9150         0.02818          0.0306        0
ga stopped because it exceeded options.MaxGenerations.
Mejor solución encontrada para 10 orientaciones:
Orientación 1: theta = 0.91°, rho = 68.37°
Orientación 2: theta = 50.83°, rho = 118.49°
Orientación 3: theta = 59.95°, rho = 104.42°
Orientación 4: theta = 44.78°, rho = 123.02°
Orientación 5: theta = 59.62°, rho = 299.35°
Orientación 6: theta = 57.73°, rho = 211.43°
Orientación 7: theta = 59.80°, rho = 216.97°
Orientación 8: theta = 59.58°, rho = 331.48°
Orientación 9: theta = 52.77°, rho = 176.67°
Orientación 10: theta = 49.00°, rho = 290.54°

RMS (costo) en esta solución: 0.028179
Información adicional:
      problemtype: 'boundconstraints'
         rngstate: [1×1 struct]
      generations: 60
        funccount: 9150
          message: 'ga stopped because it exceeded options.MaxGenerations.'
    maxconstraint: 0
       hybridflag: []


Ejecutando simulación final con orientaciones optimizadas...
Error RMS final (CDF 90%): 0.0304 m
Elapsed time is 5026.891394 seconds.


xOpt = [0.9100   68.3715   50.8276  118.4861   59.9538  104.4217   44.7810, ...
  123.0242   59.6197  299.3497   57.7300  211.4316   59.7974  216.9744,...
  59.5812  331.4844   52.7698  176.6719   49.0009  290.5383];