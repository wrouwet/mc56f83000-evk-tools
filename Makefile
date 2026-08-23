# Thin wrapper around the PowerShell scripts in tools/, for anyone who
# prefers `make` entry points. The PowerShell scripts are the primary
# interface — this just shells out to them.

PWSH := powershell.exe -NoProfile -ExecutionPolicy Bypass -File
CONFIG ?= flash_ldm_lpm_debug

.PHONY: build flash debug clean

build:
	$(PWSH) tools/Build.ps1 -Config $(CONFIG)

clean:
	$(PWSH) tools/Build.ps1 -Config $(CONFIG) -Clean

flash: build
	$(PWSH) tools/Flash.ps1 -Config $(CONFIG)

debug: build
	$(PWSH) tools/Debug.ps1 -Config $(CONFIG) -Script debug/session.tcl
