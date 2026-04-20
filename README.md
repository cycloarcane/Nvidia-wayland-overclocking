# Nvidia-wayland-overclocking

My 3090's core clock was being throttled to 210MHz due to a possible hardware issue that caused the GPU to detect phantom power draw of 150W. I suspect a faulty shunt resistor. Manually setting the power limit and clock offsets using this script fixed the issue.

## Dependencies

```sh
sudo pacman -S python-nvidia-ml-py
```

Required for core/memory clock offsets (no `nvidia-smi` equivalent on Wayland).

## Usage

```sh
sudo ./nvgpu-overclock.sh
```

The interactive script will:
1. Let you choose a preset or enter custom overclock values
2. Apply the overclock
3. Optionally install a systemd service to apply it automatically on boot

### Presets

| Preset | Power | Core | Memory (GWE) |
|---|---|---|---|
| Power only | 400W | - | - |
| Conservative | 390W | +50 MHz | +200 MHz |
| Moderate | 400W | +80 MHz | +300 MHz |
| Aggressive | 400W | +105 MHz | +400 MHz |

All values are clamped to safe limits (core 0-150 MHz, memory 0-500 MHz GWE, power 200-400W).

## Credit

**Credit to [this](https://forums.developer.nvidia.com/t/nvidia-gpu-overclocking-under-wayland-guide/290381) post.**
