from subprocess import run

from ..tool import Tool
from ..standard import Standard
from ..repository import Repository
from ..package_manager import PackageManager

class CDXGen(Tool):
    name = "cdxgen"

    def build(self) -> None:
        # Create symlink to the executable file

        self.executable.unlink(missing_ok=True)
        self.executable.symlink_to(f"{self.path}/bin/cdxgen.js")

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX

    def generate(self, repo: Repository, standard: Standard) -> None:
        output = self.output_path(repo, standard)

        project_type = {
            PackageManager.GO: "go", 
            PackageManager.GRADLE: "java", 
            PackageManager.PIP: "python"
        }[repo.package_manager]

        run([self.executable, "-t", project_type, "-o", f"{output}"], cwd=repo.path, check=False)
