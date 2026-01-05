import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn # <--- IMPORTANTE: Asegúrate de importar uvicorn si lo usas abajo

app = FastAPI()

# Configuración CORS
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
        from pyDolarVenezuela.pages import BCV, CriptoDolar
        from pyDolarVenezuela import Monitor

        # 1. BCV Dólar
        monitor_bcv = Monitor(BCV, 'USD')
        datos_bcv_usd = monitor_bcv.get_value_monitors(prettify=False)
        bcv_rate = datos_bcv_usd['bcv']['price']

        # 2. BCV Euro
        monitor_euro = Monitor(BCV, 'EUR')
        datos_bcv_eur = monitor_euro.get_value_monitors(prettify=False)
        euro_rate = datos_bcv_eur['bcv']['price']

        # 3. USDT
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        datos_cripto = monitor_cripto.get_value_monitors(prettify=False)
        usdt_rate = datos_cripto['binance']['price']

        return {
            "BCV": float(bcv_rate),
            "EURO": float(euro_rate),
            "USDT": float(usdt_rate),
            "status": "success"
        }
    except KeyError as e:
        return {"error": f"Error de clave: {str(e)}", "status": "error"}
    except Exception as e:
        return {"error": str(e), "status": "error"}

# --- ESTA ES LA PARTE QUE FALTABA ---
if __name__ == "__main__":
    # Render asigna dinámicamente el puerto en la variable de entorno PORT.
    # Si no lo usas, la app fallará en producción.
    port = int(os.environ.get("PORT", 10000)) 
    uvicorn.run(app, host="0.0.0.0", port=port)