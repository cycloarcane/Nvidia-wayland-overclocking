# Nvidia-wayland-overclocking

I found that my 3090's core clock was being throttled to 210MHz due to a possible hardware issue that caused the GPU to detect phantom power draw of 150W. I suspect a faulty shunt resistor. Manually overclocking it using these scripts seems to have permanently fixed the issue.  

## Installation

This script must be created as the root account, as it needs a root Python virtual environment.

```sh
su
cd ~ && python3 -m venv ocvenv && source ocvenv/bin/activate && pip install pynvml nvidia-ml-py
```

Put the content of `NvOverclock.desktop` in `~/.config/autostart/NvOverclock.desktop`.

## Expected Folder Structure

```
.
├── nvgpu-overclock
│   ├── overclock.py
│   └── run-nvgpu-overclock
└── ocvenv
```

- `nvgpu-overclock/`: Contains the main overclocking script and the run script.
- `ocvenv/`: Python virtual environment (contents not expanded for brevity).

## Credit

**Credit to [this](https://forums.developer.nvidia.com/t/nvidia-gpu-overclocking-under-wayland-guide/290381) post.**

