import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def clean_price(value):
    """
    Limpia el resultado independientemente de si pyDolarVenezuela 2.0.3
    devuelve un string, un float, o un objeto con propiedad price.
    """
    try:
        # Si devuelve un diccionario (algunas sub-versiones lo hacen), intentamos sacar el precio
        if isinstance(value, dict) and 'price' in value:
            value = value['price']
            
        if isinstance(value, (int, float)):
            return float(value)
            
        if isinstance(value, str):
            # Limpia 'Bs.', espacios y cambia coma por punto
            val = value.replace('Bs.', '').replace(' ', '').strip().replace(',', '.')
            return float(val)
    except Exception:
        return 0.0
    return 0.0

@app.get("/rates")
def get_rates():
    try:
        from pyDolarVenezuela.pages import BCV, CriptoDolar
        from pyDolarVenezuela import Monitor

        # 1. BCV Dólar
        # En v2.0.3 se debe pasar el argumento que pide (type_monitor)
        monitor_bcv = Monitor(BCV, 'USD')
        bcv_val = monitor_bcv.get_value_monitors(type_monitor='bcv')
        
        # 2. BCV Euro
        monitor_euro = Monitor(BCV, 'EUR')
        euro_val = monitor_euro.get_value_monitors(type_monitor='bcv')

        # 3. USDT (Binance)
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        usdt_val = monitor_cripto.get_value_monitors(type_monitor='binance')

        return {
            "BCV": clean_price(bcv_val),
            "EURO": clean_price(euro_val),
            "USDT": clean_price(usdt_val),
            "status": "success",
            "version_used": "2.0.3"
        }

    except Exception as e:
        return {"error": str(e), "status": "error"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)