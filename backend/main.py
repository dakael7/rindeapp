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
    Limpia el valor recibido (sea objeto, string o float) para devolver un float válido.
    """
    try:
        # Si el valor ya es numérico, devolverlo
        if isinstance(value, (int, float)):
            return float(value)
        
        # Si es un string (ej: "45,50"), limpiar y convertir
        if isinstance(value, str):
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

        # --- 1. BCV Dólar ---
        # Instanciamos el monitor
        monitor_bcv = Monitor(BCV, 'USD')
        # Obtenemos el objeto del monitor (pasamos el string 'bcv')
        obj_bcv = monitor_bcv.get_value_monitors("bcv")
        # Accedemos a la propiedad .price (NO ['price'])
        price_bcv = obj_bcv.price

        # --- 2. BCV Euro ---
        monitor_euro = Monitor(BCV, 'EUR')
        obj_euro = monitor_euro.get_value_monitors("bcv")
        price_euro = obj_euro.price

        # --- 3. USDT (Binance) ---
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        # En CriptoDolar el monitor suele llamarse 'binance'
        obj_cripto = monitor_cripto.get_value_monitors("binance")
        price_usdt = obj_cripto.price

        return {
            "BCV": clean_price(price_bcv),
            "EURO": clean_price(price_euro),
            "USDT": clean_price(price_usdt),
            "status": "success"
        }

    except AttributeError as e:
        return {
            "error": f"Error de atributos (posible cambio en la librería): {str(e)}",
            "status": "error"
        }
    except Exception as e:
        return {
            "error": f"Error general: {str(e)}",
            "status": "error"
        }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)