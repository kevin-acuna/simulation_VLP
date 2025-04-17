Single objective optimization:
10 Variables

Options:
CreationFcn:       @gacreationuniform
CrossoverFcn:      @crossoverscattered
SelectionFcn:      @selectionstochunif
MutationFcn:       @mutationadaptfeasible

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
    1              100         0.06803          0.3492        0
    2              150         0.06797          0.2805        0
    3              200         0.05316          0.2177        0
    4              250         0.05023          0.1573        0
    5              300          0.0482          0.1582        0
    6              350         0.04431         0.09858        0
    7              400         0.04559         0.08581        1
    8              450         0.04499         0.08299        0
    9              500         0.04556         0.08677        1
   10              550         0.04353         0.08167        0
   11              600         0.04483         0.08625        1
   12              650         0.04343          0.1233        0
   13              700         0.04321          0.1207        0
   14              750         0.04143          0.1074        0
   15              800         0.04097         0.09646        0
   16              850         0.04078         0.09409        0
   17              900         0.04047         0.09148        0
   18              950         0.04115         0.08027        1
   19             1000         0.04095         0.06863        0
   20             1050         0.04035          0.0556        0
   21             1100         0.04128         0.04717        1
   22             1150          0.0404         0.04579        0
   23             1200         0.04113         0.04586        1
   24             1250         0.04069         0.04564        0
   25             1300         0.04094         0.04511        1
   26             1350         0.04061         0.04309        0
   27             1400         0.04103         0.04324        1
   28             1450         0.04083         0.04295        0
   29             1500         0.03995         0.04294        0
   30             1550          0.0408         0.04288        1

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
   31             1600         0.04032         0.04275        0
   32             1650         0.04019         0.04263        0
   33             1700         0.03979         0.04249        0
   34             1750         0.04055         0.04266        1
   35             1800          0.0403         0.04287        0
   36             1850         0.03944         0.04232        0
   37             1900         0.03917         0.04203        0
   38             1950         0.03915         0.04197        0
   39             2000         0.03885         0.04219        0
   40             2050         0.03919         0.04218        1
   41             2100         0.03919         0.04225        2
   42             2150         0.03964         0.04174        3
   43             2200          0.0393         0.04169        0
   44             2250         0.03936         0.04195        1
   45             2300         0.03924         0.04209        0
   46             2350         0.03849         0.04132        0
   47             2400         0.03932         0.04161        1
   48             2450          0.0387         0.04148        0
   49             2500         0.03873         0.04156        1
   50             2550         0.03823         0.04129        0
ga stopped because it exceeded options.MaxGenerations.
Mejor solución encontrada para 5 orientaciones:
Orientación 1: theta = 3.97°, rho = 94.36°
Orientación 2: theta = 35.37°, rho = 332.27°
Orientación 3: theta = 36.65°, rho = 267.42°
Orientación 4: theta = 37.86°, rho = 195.46°
Orientación 5: theta = 54.54°, rho = 107.37°

RMS (costo) en esta solución: 0.038225
Información adicional:
      problemtype: 'boundconstraints'
         rngstate: [1×1 struct]
      generations: 50
        funccount: 2550
          message: 'ga stopped because it exceeded options.MaxGenerations.'
    maxconstraint: 0
       hybridflag: []


Ejecutando simulación final con orientaciones optimizadas...
Error RMS final (CDF 90%): 0.0397 m
Elapsed time is 745.286575 seconds.