from abc import ABC, abstractmethod
from pathlib import Path

from .standard import Standard
from .repository import Repository
from .paths import TOOLS, EXECUTABLES

class Tool(ABC):
    name: str

    @property
    def path(self) -> Path:
        return TOOLS / self.name
    
    @property
    def executable(self) -> Path:
        return EXECUTABLES / self.name

    def output_path(self, repo: Repository, standard: Standard) -> Path:
        return standard.path / f"{repo}.{self.name}.json"

    @abstractmethod
    def build(self) -> None:
        pass

    @abstractmethod
    def supports(self, standard: Standard) -> bool:
        pass

    @abstractmethod
    def generate(self, repo: Repository, standard: Standard):
        pass

    def __str__(self) -> str:
        return self.name
