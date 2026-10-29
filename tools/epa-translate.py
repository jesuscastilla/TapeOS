#!/usr/bin/env python3
"""TapeOS — Traduççôh a andalûh (EPA).

Êtta erramienta traduçe têttto en êppanyôh a andalûh (EPA) uçando la
biblioteka [andaluh-py](https://github.com/andalugeeks/andaluh-py) de
AndaluGeeks (kréditô en README).

Uço:
  python tools/epa-translate.py "Texto en espanol a traducir"
  echo "Texto" | python tools/epa-translate.py

Rekîçitô:
  pip install andaluh
"""

import sys

import andaluh


def main() -> None:
    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:])
    else:
        text = sys.stdin.read()
    print(andaluh.epa(text.strip()))


if __name__ == "__main__":
    main()
