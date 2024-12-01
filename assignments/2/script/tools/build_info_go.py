from subprocess import run

from ..package_manager import PackageManager
from ..repositories import Repository 
from ..standards import Standard
from ..tool import Tool

class BuildInfo(Tool):
    name = "build-info-go"

    def build(self) -> None:
        run([self.path / "buildscripts/build.sh", self.executable], cwd=self.path)

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX

    def generate(self, repo: Repository, standard: Standard) -> None:
        output = self.output_path(repo, standard)
        command = {PackageManager.GO: "go", PackageManager.GRADLE: "gradle", PackageManager.PIP: "pip"}[repo.package_manager]
        run([self.executable, command, "--format", "cyclonedx/json"], cwd=repo.path, stdout=output.open("w", encoding="utf-8"))
