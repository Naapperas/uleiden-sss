from subprocess import run

import tempfile
import os
import venv

from ..package_manager import PackageManager
from ..repository import Repository 
from ..standard import Standard
from ..tool import Tool

class BuildInfo(Tool):
    name = "build-info-go"

    def build(self) -> None:
        run([self.path / "buildscripts/build.sh", self.executable], cwd=self.path, check=False)

    def supports(self, standard: Standard) -> bool:
        return standard == Standard.CYCLONE_DX

    def generate(self, repo: Repository, standard: Standard) -> None:
        output = self.output_path(repo, standard)

        with output.open("w", encoding="utf-8") as output_file:

            if repo.package_manager == PackageManager.GO:
                run([self.executable, "go", "--format", "cyclonedx/json"], cwd=repo.path, env={**os.environ.copy(), "GOWORK": "off"}, stdout=output_file, check=True)

            elif repo.package_manager == PackageManager.PIP:
                with tempfile.TemporaryDirectory() as tmp_venv_dir:

                    builder = venv.EnvBuilder(system_site_packages=False, clear=True, symlinks=False, upgrade=False, with_pip=True)
                    builder.create(tmp_venv_dir)

                    script = """
VENV_DIR="$1"
REPO_DIR="$2"
TOOL_PATH="$3"
REPORT_DIR="$4"
                    
source "$VENV_DIR/bin/activate"
cd "$REPO_DIR"
"$TOOL_PATH" pip --format cyclonedx/json install . > "$REPORT_DIR"
deactivate
"""

                    run(["/usr/bin/bash", "-c", script, "_unused_", tmp_venv_dir, repo.path, self.executable, f"{output}"], check=True)


                    builder.clear_directory(tmp_venv_dir)

            elif repo.package_manager == PackageManager.GRADLE:
                # FIXME: WHYYYYY

                run([self.executable, "gradle", "--format", "cyclonedx/json"], cwd=repo.path, stdout=output_file, check=False)
