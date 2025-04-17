Single objective optimization:
12 Variables

Options:
CreationFcn:       @gacreationuniform
CrossoverFcn:      @crossoverscattered
SelectionFcn:      @selectionstochunif
MutationFcn:       @mutationadaptfeasible

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
    1              100         0.05904          0.3504        0
    2              150         0.05532          0.2549        0
    3              200         0.04936          0.1509        0
    4              250          0.0456          0.1135        0
    5              300         0.04202           0.102        0
    6              350         0.04353         0.08319        1
    7              400         0.04245         0.06647        0
    8              450         0.04252         0.06188        1
    9              500         0.04184         0.05531        0
   10              550         0.04193         0.05481        1
   11              600          0.0412          0.0564        0
   12              650         0.04055         0.04493        0
   13              700         0.04011          0.0445        0
   14              750         0.03981         0.04363        0
   15              800         0.03798         0.04274        0
   16              850         0.03761         0.04217        0
   17              900         0.03808          0.0411        1
   18              950         0.03671         0.04087        0
   19             1000         0.03753         0.04044        1
   20             1050         0.03687         0.04006        0
   21             1100         0.03717         0.03964        1
   22             1150         0.03659         0.03908        0
   23             1200         0.03621         0.03929        0
   24             1250          0.0366         0.03926        1
   25             1300         0.03657          0.0386        0
   26             1350           0.036         0.03864        0
   27             1400         0.03594         0.03861        0
   28             1450         0.03596         0.03861        1
   29             1500         0.03572         0.03839        0
   30             1550          0.0345         0.03816        0

                                  Best           Mean      Stall
Generation      Func-count        f(x)           f(x)    Generations
   31             1600         0.03491         0.03827        1
   32             1650         0.03452          0.0378        0
   33             1700         0.03544         0.03739        1
   34             1750         0.03493         0.03761        0
   35             1800         0.03507          0.0374        1
   36             1850         0.03504         0.03731        0
   37             1900         0.03427         0.03708        0
   38             1950         0.03496         0.03704        1
   39             2000          0.0342         0.03666        0
   40             2050         0.03475         0.03671        1
   41             2100          0.0339         0.03634        0
   42             2150         0.03359         0.03611        0
   43             2200         0.03409         0.03615        1
   44             2250         0.03316         0.03604        0
   45             2300         0.03386         0.03623        1
   46             2350         0.03353         0.03578        0
   47             2400         0.03245         0.03559        0
   48             2450         0.03333         0.03523        1
   49             2500         0.03267         0.03537        0
   50             2550         0.03322         0.03525        1
ga stopped because it exceeded options.MaxGenerations.
Mejor solución encontrada para 6 orientaciones:
Orientación 1: theta = 4.89°, rho = 304.66°
Orientación 2: theta = 14.39°, rho = 135.90°
Orientación 3: theta = 49.17°, rho = 331.28°
Orientación 4: theta = 43.57°, rho = 95.40°
Orientación 5: theta = 58.37°, rho = 167.95°
Orientación 6: theta = 46.84°, rho = 303.82°

RMS (costo) en esta solución: 0.033222
Información adicional:
      problemtype: 'boundconstraints'
         rngstate: [1×1 struct]
      generations: 50
        funccount: 2550
          message: 'ga stopped because it exceeded options.MaxGenerations.'
    maxconstraint: 0
       hybridflag: []


Ejecutando simulación final con orientaciones optimizadas...
Error RMS final (CDF 90%): 0.0367 m
Elapsed time is 882.509643 seconds.