"""
exp02_database.py - Experimento 02: adquisicion de la base de datos (rejilla XYZ x K angulos).

Ejecutar:
    python tests/experiments/exp02_database/exp02_database.py

Abre la interfaz en el navegador (http://127.0.0.1:8765). Desde ahi:
  1. Configurar la rejilla (inicio / fin / paso de X, Y, Z), K angulos del MTRS, el tilt
     mecanico del PD (solo se registra), muestras por orientacion y frecuencias.
  2. "Preview": se muestran las posiciones y el recorrido, el numero de mediciones, la
     duracion estimada y el espacio en disco. Se puede reconfigurar las veces necesarias.
  3. "Start": el PD recorre el plan; cada medicion terminada se pinta en el mapa.
     "Pause" (al terminar la medicion actual), "Resume" y "Stop" (inmediato).

Todo el control es Python (engine.py); la pagina web solo envia comandos y muestra el
estado. Cerrar el navegador NO detiene la adquisicion: se puede volver a abrir la URL.
Para terminar el programa: Ctrl+C en esta consola (detiene el movimiento y cierra todo).

Los parametros de los EQUIPOS estan en config/testbed.toml.
"""

import os
import sys
import time
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))          # implementation/tests
sys.path.insert(0, ROOT)
sys.path.insert(0, HERE)

from engine import Engine                   # noqa: E402
from hardware.testbed import Testbed        # noqa: E402
from server import make_server, serve_in_thread   # noqa: E402


# ============================================================
# HIPERPARAMETROS DEL EXPERIMENTO
# ============================================================

DEVICE_MODE_OVERRIDE = {}            # p.ej. {"gantry": "sim", "mtrs": "sim"}; vacio = config
HOST, PORT = "127.0.0.1", 8765       # direccion de la interfaz web
OPEN_BROWSER = True                  # abrir el navegador al arrancar
OUTPUT_ROOT = os.path.join(ROOT, "data", "exp02")

# Valores iniciales del panel de configuracion (se pueden cambiar en la interfaz)
DEFAULT_CONFIG = {
    "x": [100.0, 1300.0, 300.0],             # inicio, fin, paso [mm]
    "y": [100.0, 1300.0, 300.0],
    "z": [-300.0, -300.0, 100.0],            # Z = -700 posicion mas alta del PD, Z = 0 la mas baja
    "k_angles": 4,                           # K angulos: (offset + 360*k/K) mod 360
    "angle_offset_deg": 65.0,                # offset de orientacion (K=4 -> 65, 155, 245, 335)
    "pd_tilt_deg": 15.0,                     # inclinacion mecanica de la pieza 3D (SOLO registro)
    "n_samples": 1,                          # adquisiciones por orientacion (sin moverse)
    "n_passes": 1,                           # veces que se repite TODO el recorrido (varianza por
                                             # punto); las pasadas impares van en sentido contrario
    "freqs_khz": [300.0, 500.0, 700.0, 900.0],
    "settle_s": 1.0,                         # espera tras llegar, antes de medir
    "record_ms": 100.0,                      # registro CONTINUO por muestra [ms]; 0 = usar lo
                                             # configurado en el osciloscopio. Se restaura al final
    "record_fs_msa": 10.0,                   # frecuencia de muestreo del registro [MSa/s]
                                             # (100 ms x 10 MSa/s = 1 M puntos; maximo 4 M)
    "scope_fft": False,                      # True: leer tambien la FFT del osciloscopio (+~1.4 s
                                             # por muestra y solo usa 64K puntos); False: FFT en Python
    "serpentine_xy": True,                   # recorrido XY en serpentina
    "serpentine_angles": True,               # angulos alternados (sin vuelta a 0, cable seguro)
    "save_waveforms": True,                  # guardar la onda cruda (wave/*.npz)
    "time_points": 8000000,                  # puntos de onda pedidos (8e6 = todos los del registro)
    "label": "",                             # sufijo opcional del nombre de la sesion
}


def main():
    tb = Testbed(modes=DEVICE_MODE_OVERRIDE)
    engine = server = None
    try:
        tb.connect()
        engine = Engine(tb, OUTPUT_ROOT, DEFAULT_CONFIG)
        engine.start_threads()
        server = make_server(engine, HOST, PORT)
        serve_in_thread(server)
        url = f"http://{HOST}:{server.server_address[1]}"
        print(f"\n[exp02] Interface: {url}   (Ctrl+C here to quit)\n")
        if OPEN_BROWSER:
            webbrowser.open(url)
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[exp02] Ctrl+C: stopping...")
    finally:
        if engine is not None:
            engine.shutdown()
        if server is not None:
            server.shutdown()
        tb.close()


if __name__ == "__main__":
    main()
