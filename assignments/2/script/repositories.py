from enum import StrEnum, property
from pathlib import Path

from .paths import REPOSITORIES
from .package_manager import PackageManager

class Repository(StrEnum):
    KAFKA = ("kafka", PackageManager.GRADLE)
    KUBERNETES = ("kubernetes", PackageManager.GO)
    NUMPY = ("numpy", PackageManager.PIP)

    def __new__(cls, value, package_manager):
        member = str.__new__(cls, value)
        member._value_ = value
        member.package_manager = package_manager
        return member

    @property
    def path(self) -> Path:
        return REPOSITORIES / self
