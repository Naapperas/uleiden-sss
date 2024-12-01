from enum import StrEnum, property
from pathlib import Path

from .paths import REPORTS

class Standard(StrEnum):
    CYCLONE_DX = "CycloneDX"
    SPDX = "SPDX"
    SWID = "SWID"

    @property
    def path(self) -> Path:
        return REPORTS / self