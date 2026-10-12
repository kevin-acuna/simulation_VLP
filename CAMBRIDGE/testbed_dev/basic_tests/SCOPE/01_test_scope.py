"""
01_test_scope.py

Lista los instrumentos VISA y pregunta *IDN? a cada uno.
"""

import pyvisa

# Puertos COM (ASRL): pueden ser otros equipos (controladores Thorlabs, etc.)
# que no hablan SCPI; por defecto no se les envia *IDN?.
QUERY_SERIAL_PORTS = False

# Direcciones LAN que no aparecen en la lista (p.ej. si no se agregaron en
# Keysight Connection Expert): "TCPIP0::192.168.1.50::hislip0::INSTR"
EXTRA_ADDRESSES = []

TIMEOUT_MS = 3000


rm = pyvisa.ResourceManager()
print(f"Libreria VISA: {rm}")

resources = list(rm.list_resources("?*::INSTR")) + EXTRA_ADDRESSES

if not resources:
    print("\nNo se detecto ningun instrumento.")
    print("  - USB: revisa el cable y que el osciloscopio este encendido.")
    print("  - LAN: agrega el instrumento en Keysight Connection Expert o en EXTRA_ADDRESSES.")

print("\nInstrumentos detectados:")
for resource in resources:
    print(resource)

    if resource.startswith("ASRL") and not QUERY_SERIAL_PORTS:
        print("  (puerto serie, omitido)")
        continue

    try:
        with rm.open_resource(resource) as instrument:
            instrument.timeout = TIMEOUT_MS
            identity = instrument.query("*IDN?")
        print("  ID:", identity.strip())

    except pyvisa.VisaIOError as e:
        print("  No responde:", e)

rm.close()
