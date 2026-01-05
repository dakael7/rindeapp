import sys
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

try:
    from pydolarvenezuela.pages import BCV, CriptoDolar
    from pydolarvenezuela.monitor import Monitor
except ImportError as e:
    print(f"CRITICAL ERROR: No se pudo importar pydolarvenezuela. Python Path: {sys.path}")
    print(f"Error details: {e}")
    # No detenemos la app aquí para permitir que al menos arranque y muestre el error en logs

app = FastAPI()

# Configuración CORS para permitir peticiones desde Flutter Web (cualquier origen)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def health_check():
    """Endpoint para verificar que el servidor está vivo"""
    return {"status": "ok", "message": "Rinde API is running", "python_version": sys.version}

@app.get("/rates")
def get_rates():
    try:
        # Importar aquí dentro también por seguridad si falló arriba
        from pydolarvenezuela.pages import BCV, CriptoDolar
        from pydolarvenezuela.monitor import Monitor

        # 1. Obtener Tasa BCV (Dólar)
        monitor_bcv = Monitor(BCV, 'USD')
        bcv_rate = monitor_bcv.get_value_monitors(monitor_code='bcv', name_property='price', pretty=False)

        # 2. Obtener Tasa BCV (Euro)
        monitor_euro = Monitor(BCV, 'EUR')
        euro_rate = monitor_euro.get_value_monitors(monitor_code='bcv', name_property='price', pretty=False)

        # 3. Obtener Tasa USDT (Binance P2P)
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        usdt_rate = monitor_cripto.get_value_monitors(monitor_code='binance', name_property='price', pretty=False)

        return {
            "BCV": float(bcv_rate),
            "EURO": float(euro_rate),
            "USDT": float(usdt_rate),
            "status": "success"
        }
    except Exception as e:
        return {
            "error": str(e),
            "status": "error"
        }