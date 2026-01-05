import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

# Configuración CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def clean_price(value):
    """
    Función auxiliar para limpiar el precio sin importar cómo lo devuelva la librería.
    Maneja strings como '50,12', 'Bs. 50.12' o floats directos.
    """
    if isinstance(value, (int, float)):
        return float(value)
    
    if isinstance(value, str):
        # Eliminamos símbolos de moneda y espacios si existen
        clean_val = value.replace('Bs.', '').replace(' ', '').strip()
        # Cambiamos la coma decimal por punto (formato inglés para Python)
        clean_val = clean_val.replace(',', '.')
        try:
            return float(clean_val)
        except ValueError:
            return 0.0
    return 0.0

@app.get("/rates")
def get_rates():
    try:
        from pyDolarVenezuela.pages import BCV, CriptoDolar
        from pyDolarVenezuela import Monitor

        # 1. BCV Dólar
        monitor_bcv = Monitor(BCV, 'USD')
        # RETIRADO: prettify=False (causaba el error)
        datos_bcv_usd = monitor_bcv.get_value_monitors() 
        bcv_rate = clean_price(datos_bcv_usd['bcv']['price'])

        # 2. BCV Euro
        monitor_euro = Monitor(BCV, 'EUR')
        # RETIRADO: prettify=False
        datos_bcv_eur = monitor_euro.get_value_monitors()
        euro_rate = clean_price(datos_bcv_eur['bcv']['price'])

        # 3. USDT
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        # RETIRADO: prettify=False
        datos_cripto = monitor_cripto.get_value_monitors()
        usdt_rate = clean_price(datos_cripto['binance']['price'])

        return {
            "BCV": bcv_rate,
            "EURO": euro_rate,
            "USDT": usdt_rate,
            "status": "success"
        }
    except KeyError as e:
        return {"error": f"Error de estructura de datos: {str(e)}", "status": "error"}
    except Exception as e:
        return {"error": str(e), "status": "error"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)