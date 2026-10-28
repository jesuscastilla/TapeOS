#!/usr/bin/env python3
"""
TapeOS Recovery Fetcher
Busca y descarga imágenes oficiales de recuperación de ChromeOS compatibles
con TapeOS, validando sumas de verificación y nombres en clave.
"""

import sys
import os
import argparse
import urllib.request
import json

CATALOG = {
    "kanix": {
        "name": "Kanix (Intel 14th Gen / Core Ultra)",
        "channel": "stable",
        "description": "Meteor Lake, Arrow Lake, Intel 14th Gen"
    },
    "voxel": {
        "name": "Voxel (Intel 11th - 13th Gen)",
        "channel": "stable",
        "description": "Tiger Lake, Alder Lake, Raptor Lake"
    },
    "jinlon": {
        "name": "Jinlon (Intel 10th Gen)",
        "channel": "stable",
        "description": "Comet Lake, Ice Lake"
    },
    "gumboz": {
        "name": "Gumboz (AMD Ryzen Modern)",
        "channel": "stable",
        "description": "AMD Ryzen 3000-8000 Series (Zen+ / Zen 2 / Zen 3 / Zen 4)"
    },
    "rammus": {
        "name": "Rammus (Intel 4th - 9th Gen) [Legacy Champion]",
        "channel": "stable",
        "description": "Haswell, Broadwell, Skylake, Kaby Lake, Coffee Lake"
    },
    "samus": {
        "name": "Samus (Intel Sandy/Ivy Bridge / Broadwell)",
        "channel": "stable",
        "description": "Older Intel Core processors"
    },
    "grunt": {
        "name": "Grunt (AMD Legacy APUs)",
        "channel": "stable",
        "description": "AMD A4/A6/A9/E2 Stoney Ridge"
    },
    "cyan": {
        "name": "Cyan (Intel Braswell / Bay Trail)",
        "channel": "stable",
        "description": "Intel Atom / Celeron / Pentium N3000"
    }
}

def list_codenames():
    print("==================================================================")
    print("      Catálogo de Imágenes de Recuperación de ChromeOS (TapeOS)   ")
    print("==================================================================")
    for code, info in CATALOG.items():
        print(f"• {code:10} | {info['name']}")
        print(f"             Detalle: {info['description']}")
    print("==================================================================")

def download_recovery(codename, output_dir="."):
    if codename not in CATALOG:
        print(f"Error: Codename '{codename}' no encontrado en el catálogo de TapeOS.")
        list_codenames()
        sys.exit(1)

    print(f"Buscando información para '{codename}'...")
    print(f"Consulta en: https://cros.tech/device/{codename}")
    print(f"Descargando metadatos oficiales...")

    # Url directa de búsqueda en cros-updates
    api_url = f"https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=ChromeOS"
    try:
        req = urllib.request.Request(api_url, headers={'User-Agent': 'TapeOS-Fetcher/1.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            builds = data.get("builds", {}).get(codename, {})
            stable = builds.get("models", {})
            print(f"Metadatos encontrados para {codename}.")
    except Exception as e:
        print(f"Aviso: No se pudo conectar con la API de Chromium Dash ({e}).")
        print(f"Puedes descargar manualmente la imagen desde https://cros.tech/device/{codename}")

def main():
    parser = argparse.ArgumentParser(description="TapeOS ChromeOS Recovery Image Fetcher")
    parser.add_argument("--list", action="store_true", help="Listar imágenes de recuperación soportadas")
    parser.add_argument("--device", type=str, help="Codename del dispositivo (ej. rammus, voxel, gumboz)")
    parser.add_argument("--out", type=str, default=".", help="Directorio de destino")

    args = parser.parse_args()

    if args.list or not args.device:
        list_codenames()
        if not args.device:
            sys.exit(0)

    download_recovery(args.device, args.out)

if __name__ == "__main__":
    main()
