# Keeps THIS project's heavy processes (Godot from tools/godot, the project's Python)
# on logical CPUs 0-11 at below-normal priority, so long multi-agent builds do not
# overheat the PC. Processes of other projects are never touched. Runs until stopped:
#   powershell -NoProfile -File tools/agents/cpu_cap.ps1
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$mask = [IntPtr]0x000FFF
$names = @('Godot_v4.7.2-stable_win64_console', 'Godot_v4.7.2-stable_win64', 'python')
while ($true) {
	foreach ($p in Get-Process -Name $names -ErrorAction SilentlyContinue) {
		try {
			if (-not $p.Path -or -not $p.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
			if ($p.ProcessorAffinity -ne $mask) { $p.ProcessorAffinity = $mask }
			if ($p.PriorityClass -ne 'BelowNormal') { $p.PriorityClass = 'BelowNormal' }
		} catch { }
	}
	Start-Sleep -Seconds 3
}
