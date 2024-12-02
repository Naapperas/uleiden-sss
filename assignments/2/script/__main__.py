from __future__ import print_function

import traceback
from itertools import product

import chalk

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
    print(chalk.green(chalk.bold("Building tools...")))

    errored = False
    for tool in TOOLS:
        try:
            print(chalk.green(f"Building {chalk.bold(str(tool))}..."))
            tool.build()
        except Exception as e:
            errored = True
            error(chalk.red(f"Failed to build {chalk.bold(str(tool))}"))
            error(traceback.format_exc())
    if errored:
        error(chalk.red("Some tools failed to build, exiting..."))
        exit(1)

    print(chalk.green(chalk.bold("Generating reports...")))
    for repo, standard, tool in product(Repository, Standard, TOOLS):
        if tool.supports(standard):
            try:
                print(chalk.green(f"Generating {chalk.bold(str(standard))} report for {chalk.bold(str(repo))} using {chalk.bold(str(tool))}..."))
                tool.generate(repo, standard)
            except Exception as e:
                error(chalk.red(f"Failed to generate {chalk.bold(str(standard))} report for {chalk.bold(str(repo))} using {chalk.bold(str(tool))}"))
                error(traceback.format_exc())
        else:
            error(chalk.yellow(f"{tool} does not support {standard}, skipping"))

if __name__ == '__main__':
    main()
