from subprocess import run

from ..repository import Repository
from ..standard import Standard
from ..tool import Tool

class Syft(Tool):
    name = "syft"

    def build(self) -> None:
        run(["make", "build"], cwd=self.path, check=False)

        output = next(self.path.glob("snapshot/*/syft"))
        
        self.executable.unlink(missing_ok=True)
        self.executable.symlink_to(output)

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX or standard == Standard.SPDX

    def generate(self, repo: Repository, standard: Standard) -> None:
        output = self.output_path(repo, standard)
        
        fmt = "spdx-json" if standard == Standard.SPDX else "cyclonedx-json"

        run([self.executable, "scan", f"dir:{repo.path}", "--enrich", "all", "-o", f"{fmt}={output}"], check=False)
