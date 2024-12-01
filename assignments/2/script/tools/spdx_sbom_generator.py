from subprocess import run
from pathlib import Path
from shutil import move

from ..package_manager import PackageManager
from ..repository import Repository
from ..standard import Standard
from ..tool import Tool

class SpdxSbomGenerator(Tool):
    name = "spdx-sbom-generator"

    def build(self) -> None:
        run(["make", "build"], cwd=self.path)
        output = self.path / "bin/spdx-sbom-generator"
        self.executable.unlink(missing_ok=True)
        self.executable.symlink_to(output)
    
    def supports(self, standard: Standard) -> bool:
        return standard == Standard.SPDX
    
    def generate(self, repo: Repository, standard: Standard) -> None:
        output = self.output_path(repo, standard)
        tmp = Path("/tmp/spdx-sbom-generator")
        tmp.mkdir(exist_ok=True)
        run([self.executable, "--path", repo.path, "--output-dir", tmp, "--format", "json"])
        tmp_out = next(tmp.glob("*.json"))
        move(tmp_out, output)
        tmp.rmdir()
