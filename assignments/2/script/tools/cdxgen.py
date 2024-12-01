from ..tool import Tool
from ..standards import Standard
from ..repositories import Repository

class CDXGen(Tool):
    name = "cdxgen"

    def build(self) -> None:
        pass

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX

    def generate(self, repo: Repository, standard: Standard) -> str:
        pass
