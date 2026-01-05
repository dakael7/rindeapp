@app.get("/rates")
def get_rates():
    try:
        # Importaciones
        from pyDolarVenezuela.pages import BCV, CriptoDolar
        from pyDolarVenezuela import Monitor

        # 1. Obtener Tasa BCV (Dólar)
        monitor_bcv = Monitor(BCV, 'USD')
        # Obtenemos TODOS los datos de la página BCV sin argumentos de filtrado
        datos_bcv_usd = monitor_bcv.get_value_monitors(prettify=False)
        # Accedemos manualmente a la clave 'bcv' y luego al 'price'
        bcv_rate = datos_bcv_usd['bcv']['price']

        # 2. Obtener Tasa BCV (Euro)
        monitor_euro = Monitor(BCV, 'EUR')
        datos_bcv_eur = monitor_euro.get_value_monitors(prettify=False)
        # Accedemos manualmente
        euro_rate = datos_bcv_eur['bcv']['price']

        # 3. Obtener Tasa USDT (Binance P2P)
        monitor_cripto = Monitor(CriptoDolar, 'USD')
        datos_cripto = monitor_cripto.get_value_monitors(prettify=False)
        # En CriptoDolar, la clave suele ser 'binance'
        usdt_rate = datos_cripto['binance']['price']

        return {
            "BCV": float(bcv_rate),
            "EURO": float(euro_rate),
            "USDT": float(usdt_rate),
            "status": "success"
        }
    except KeyError as e:
        # Capturamos error si cambia el nombre de la clave (ej. si 'bcv' cambia de nombre)
        return {
            "error": f"Clave no encontrada en la respuesta de pyDolar: {str(e)}",
            "status": "error"
        }
    except Exception as e:
        return {
            "error": str(e),
            "status": "error"
        }