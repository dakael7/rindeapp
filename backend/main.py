from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydolarvenezuela.pages import BCV, CriptoDolar
from pydolarvenezuela.monitor import Monitor

app = FastAPI()

# Configuración CORS para permitir peticiones desde Flutter Web (cualquier origen)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/rates")
def get_rates():
    try:
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