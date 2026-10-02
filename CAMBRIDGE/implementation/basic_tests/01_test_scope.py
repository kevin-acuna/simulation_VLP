import pyvisa

rm = pyvisa.ResourceManager()

resources = rm.list_resources()

print("Detected instruments:")
for resource in resources:
    print(resource)

    try:
        instrument = rm.open_resource(resource)
        instrument.timeout = 5000

        identity = instrument.query("*IDN?")

        print("  ID:", identity.strip())

        instrument.close()

    except Exception as e:
        print("  Unable to communicate:", e)