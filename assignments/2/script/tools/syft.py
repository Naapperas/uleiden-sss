from subprocess import run

from ..repositories import Repository
from ..standards import Standard
from ..tool import Tool

class Syft(Tool):
    name = "syft"

    def build(self) -> None:
        run(["make", "build"], cwd=self.path)
        output = next(self.path.glob("snapshot/*/syft"))
        self.executable.unlink(missing_ok=True)
        self.executable.symlink_to(output)

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX or standard == Standard.SPDX

    def generate(self, repo: Repository, standard: Standard):
        fmt = "spdx-json" if standard == Standard.SPDX else "cyclonedx"
        output = self.output_path(repo, standard)

        run([self.executable, "scan", f"dir:{repo.path}", "--enrich", "all", "-o", f"{fmt}={output}"])