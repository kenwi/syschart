# syschart

Log your machine's **CPU usage**, memory/swap usage, load average and CPU
temperature, then chart it — in your terminal or in an interactive window.

All metrics are read straight from `/proc` and sysfs, so everything runs in
userspace with no root required.

## Features

- Lightweight bash sampler with a systemd user service (5s sampling by default)
- Tab-separated log with timestamp, CPU %, memory/swap % and used MiB,
  load 1m, CPU temp
- Terminal charts with Unicode bars — no extra dependencies
- Interactive matplotlib window to probe exact values at a given time (`--show`)
- Optional PNG export (default ~1800px wide; override with `--size WxH`)
- No root required; everything runs in userspace

## Requirements

- Linux with `/proc` (universal) — temperature needs a supported hwmon
  driver (Intel `coretemp`, AMD `k10temp`, …) and is optional
- `bash`, `date`, `awk`
- Python 3 (only for `syschart --show` / `--png`; terminal chart is plain stdlib)
- matplotlib (optional, for `--show` / `--png`)
- systemd user session (optional — sampling can also run without it)

## Install

Clone and run the installer:

```bash
git clone https://github.com/you/syschart.git
cd syschart
./install.sh                 # default 5s sampling
./install.sh --interval 10   # sample every 10 seconds
```

This installs:

```
~/.local/bin/sysprobe
~/.local/bin/syschart
~/.config/systemd/user/sysprobe.service   (enabled + started)
```

Log data accumulates at `~/.local/state/sysprobe/sys.log`.

### Manual install

```bash
install -m 0755 bin/sysprobe    ~/.local/bin/sysprobe
install -m 0755 bin/syschart    ~/.local/bin/syschart
mkdir -p ~/.config/systemd/user
cp systemd/sysprobe.service      ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now sysprobe
```

## Usage

### Service control

```bash
systemctl --user status sysprobe
systemctl --user restart sysprobe
systemctl --user stop sysprobe
systemctl --user disable --now sysprobe
```

Log a single sample manually at any time:

```bash
sysprobe --once
```

### Charting

```bash
syschart                 # last 60 minutes: CPU % + memory %
syschart --since 15m     # last 15 minutes
syschart --all           # entire log
syschart --absolute      # memory/swap as used MiB/GiB instead of %
syschart --swap          # also show swap usage
syschart --load          # also show 1-minute load average
syschart --temp          # also show CPU temperature
syschart --show          # interactive window; hover to probe exact values
syschart --png           # render PNG to /tmp/syschart.png and open it
syschart --png ~/p.png   # PNG to a custom path
syschart --size 875x600  # fixed pixel size for --png / --show
syschart --theme dark    # dark plot background (also works with --show)
syschart --help          # all options
```

Terminal output example:

```
System usage — 0:15:00  (180 samples)
CPU %    now 23.4  ▁▁▂▃▅█▆▃▂▂▄▇▂▁▁  peak 87.1 / avg 24.9 / min 3.2
Mem %    now 61.2  ████████████████  peak 63.0 / avg 62.1 / min 60.8
         18:00:01                                    18:15:00
```

## Log format

Tab-separated, one line per sample:

```
#timestamp	cpu_pct	mem_pct	swap_pct	load1	temp_c	mem_used_mib	swap_used_mib
2026-08-21T18:25:01	23.4	61.2	12.4	1.25	45	4832	951
```

`temp_c` is empty when no CPU temperature sensor is found. Logs written by
older versions lack the two `*_mib` columns; they chart fine except for
`--absolute`.

## Customization

| Variable | Default | Effect |
| --- | --- | --- |
| `SYSPROBE_INTERVAL` | `5` | Seconds between samples |
| `SYSPROBE_FILE` | `~/.local/state/sysprobe/sys.log` | Log file path |

Change the service's interval by editing the `--interval` value in
`~/.config/systemd/user/sysprobe.service`, then:

```bash
systemctl --user daemon-reload && systemctl --user restart sysprobe
```

### Keybinding (Hyprland example)

```conf
bindd = SUPER, M, System chart (PNG 875x600), exec, /home/you/.local/bin/syschart --png --size 875x600 --temp --load
```

## Uninstall

```bash
./install.sh --uninstall
```

This disables and removes the service, the scripts, and the log data.

## Understanding the numbers

- **CPU %** is total utilization across all cores, computed from the delta of
  `/proc/stat` counters since the previous sample. The very first sample after
  installation reports the average since boot instead.
- **Mem %** is `(MemTotal − MemAvailable) / MemTotal`, i.e. memory that
  programs are actually using — page cache is *not* counted as used.
  `--absolute` reports the same quantity in MiB/GiB (switching units on the
  plot automatically when the range gets large).
- **Load** is the classic 1-minute load average: runnable + uninterruptible
  tasks. Sustained values near or above your core count mean saturation.

## Notes

- The log grows ~55 KB per 1000 samples (~950 KB/day at 5-second sampling) —
  trim or rotate `sys.log` occasionally if you chart `--all` on old data.
