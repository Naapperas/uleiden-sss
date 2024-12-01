import traceback
from itertools import product

from .repository import Repository
from .standard import Standard
from .util import error

from .tools.build_info_go import BuildInfo
from .tools.cdxgen import CDXGen
from .tools.spdx_sbom_generator import SpdxSbomGenerator
from .tools.syft import Syft

TOOLS = {
    BuildInfo(),
    CDXGen(),
    SpdxSbomGenerator(),
    Syft(),
}

def main():
    print("Building tools...")

    errored = False
    for tool in TOOLS:
        try:
            print(f"Building {tool}...")
            tool.build()
        except Exception as e:
            errored = True
            error(f"Failed to build {tool}")
            error(traceback.format_exc())
    if errored:
        error("Some tools failed to build, exiting...")
        exit(1)

    print("Generating reports...")
    for repo, standard, tool in product(Repository, Standard, TOOLS):
        if tool.supports(standard):
            try:
                print(f"Generating {standard} report for {repo} using {tool}...")
                tool.generate(repo, standard)
            except Exception as e:
                error(f"Failed to generate {standard} report for {repo} using {tool}")
                error(traceback.format_exc())
        else:
            error(f"{tool} does not support {standard}, skipping")

if __name__ == '__main__':
    main()
