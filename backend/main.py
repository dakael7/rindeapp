import sys
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Inicialización de la aplicación FastAPI
app = FastAPI()

# Configuración de CORS para permitir acceso desde cualquier origen (Flutter Web, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def extract_price_safe(monitor_data):
    """
    Extrae el precio de forma segura analizando la estructura devuelta por get_all_monitors.
    Funciona si devuelve lista, diccionario o un solo objeto.
    """
    try:
        # Caso 1: Es una lista de objetos (común en get_all_monitors)
        if isinstance(monitor_data, list):
            for item in monitor_data:
                # Buscamos atributos comunes de precio
                if hasattr(item, 'price'): return clean_price(item.price)
                if isinstance(item, dict) and 'price' in item: return clean_price(item['price'])

        # Caso 2: Es un diccionario directo
        if isinstance(monitor_data, dict):
            # A veces la clave es 'bcv', 'usd', o el mismo diccionario tiene 'price'
            if 'price' in monitor_data: return clean_price(monitor_data['price'])
            for key, val in monitor_data.items():
                if isinstance(val, dict) and 'price' in val:
                    return clean_price(val['price'])
                if hasattr(val, 'price'):
                    return clean_price(val.price)

        # Caso 3: Es un objeto único con propiedad price
        if hasattr(monitor_data, 'price'):
            return clean_price(monitor_data.price)
            
    except Exception:
        pass
    return 0.0

def clean_price(value):
    """Convierte cualquier formato de precio (texto con comas, bs, etc.) a float."""
    try:
        if isinstance(value, (int, float)): return float(value)
        if isinstance(value, str):
            # Limpieza estándar: quitar Bs., espacios y cambiar coma a punto
            return float(value.replace('Bs.', '').replace(' ', '').strip().replace(',', '.'))
    except:
        return 0.0
    return 0.0

@app.get("/rates")
def get_rates():
    """
    Obtiene las tasas usando get_all_monitors() para evitar errores de clave no encontrada.
    """
    try:
        from pyDolarVenezuela.pages import BCV, CriptoDolar
        from pyDolarVenezuela import Monitor

        # --- 1. BCV Dólar ---
        # Usamos get_all_monitors() para evitar el error "Key not found"
        try:
            monitor_bcv = Monitor(BCV, 'USD')
            data_bcv = monitor_bcv.get_all_monitors()
            price_bcv = extract_price_safe(data_bcv)
        except Exception:
            price_bcv = 0.0

        # --- 2. BCV Euro ---
        try:
            monitor_euro = Monitor(BCV, 'EUR')
            data_euro = monitor_euro.get_all_monitors()
            price_euro = extract_price_safe(data_euro)
        except Exception:
            price_euro = 0.0

        # --- 3. USDT (Binance) ---
        try:
            monitor_cripto = Monitor(CriptoDolar, 'USD')
            # CriptoDolar a veces requiere una llamada específica, intentamos safe
            data_cripto = monitor_cripto.get_all_monitors()
            price_usdt = extract_price_safe(data_cripto)
        except Exception:
            price_usdt = 0.0

        return {
            "BCV": price_bcv,
            "EURO": price_euro,
            "USDT": price_usdt,
            "status": "success"
        }

    except Exception as e:
        return {
            "error": str(e),
            "status": "error"
        }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)