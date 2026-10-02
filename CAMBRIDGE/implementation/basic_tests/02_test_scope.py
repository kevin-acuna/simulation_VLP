import pyvisa

rm = pyvisa.ResourceManager()

print("VISA resources detected:")
print(rm.list_resources())