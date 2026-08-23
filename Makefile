# Thin wrapper around the PowerShell scripts in tools/, for anyone who
# prefers `make` entry points. The PowerShell scripts are the primary
# interface — this just shells out to them.

PWSH := powershell.exe -NoProfile -ExecutionPolicy Bypass -File

.PHONY: build flash run debug clean

build:
	$(PWSH) tools/Build.ps1

clean:
	$(PWSH) tools/Build.ps1 -Clean

flash: build
	$(PWSH) tools/Flash.ps1

run: build
	$(PWSH) tools/Flash.ps1 -Run

debug: build
	$(PWSH) tools/Debug.ps1 -Script debug/session.tcl
