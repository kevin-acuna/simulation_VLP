"""
Controladores reutilizables del testbed OWP (Cambridge).

Uso normal (lee config/testbed.toml, donde se configuran los equipos una sola vez):

    from hardware.testbed import Testbed
    with Testbed() as tb:
        tb.go_to_pose((700, 700, -300), 144)
        acqs = tb.scope.record(3, 100000)

Modulos:
    testbed.Testbed   crea/conecta los equipos segun la config + metodos conjuntos
    gantry.Gantry     igus DLE-RG-0012-BLDC via CRI (cri_lib)
    mtrs.MTRS         Thorlabs MTRS via Kinesis .NET (pythonnet)
    scope.Scope       Keysight/Agilent InfiniiVision (MSO-X 4154A) via pyvisa
    sim.*             versiones simuladas con la misma interfaz (pruebas sin hardware)
"""
