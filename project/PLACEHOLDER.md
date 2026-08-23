# A real CodeWarrior Eclipse project goes here

`ecd.exe` (CodeWarrior's headless build driver — see docs/ARCHITECTURE.md) builds a
whole **Eclipse project directory** (one containing a `.cproject`/`.project` file),
not loose source files. So this folder needs to directly contain one.

Fastest way to get a known-correct one, from the MCUXpresso SDK for
MC56F83000-EVK (confirmed real: `SDK_2.7.1_MC56F83000-EVK` — see
docs/SETUP.md step 5 for where to get it):

- **To verify the whole pipeline works first**: copy the contents of
  `<sdk_install>/boards/evkmc56f83000/demo_apps/hello_world/codewarrior/`
  into this folder. It's a UART "hello world" over the OSJTAG COM port —
  confirmed working per NXP's own getting-started guide.
- **To start your own application**: copy the contents of
  `<sdk_install>/boards/evkmc56f83000/driver_examples/gpio/button_toggle_led/codewarrior/`
  (the real on-board LED example) instead, or download the
  `project_template_MC56F83789` package (linked from the SDK docs, per
  device part number) for a minimal starting point with just startup code,
  device headers, and a linker file — no demo application logic.

Either way, delete this placeholder once real project files are here. The
build config names NXP documents for this board are `flash_ldm_lpm_debug`
and `flash_ldm_lpm_release` — `tools/Build.ps1` defaults to the former.
