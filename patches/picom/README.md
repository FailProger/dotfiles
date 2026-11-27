PICOM INSTALLATION
---

## Warning
It is not official repo. It is my configuration base on `picom` form - `pijulius/picom`.

For more about this `picom` fork see author: `https://github.com/pijulius/picom`. For origin `picom` see master repo `https://github.com/yshui/picom`.

---

## How install
1. Clone and patch `pijulius/picom` (**NOT** `yshui/picom`)
2. First patch `my-patches.diff`
3. Copy `animation_presets.conf` to `data/animation_presets.conf`
4. Setup project and compile `animgen` with *meson*
5. Generate `script_templates.c`
6. Build and install `picom` with *ninja*

### Step by step
Clone with repo:
```
git clone --depth 1 'https://github.com/FailProger/dotfiles'
cd dotfiles/patches/picom
```

Clone `pijulius/picom` from `next` branch (*default*) and patch:
```
git clone --depth 1 'https://github.com/pijulius/picom'
cd picom
patch -p1 < ../my-pacthes.diff
cp ../animation_presets.conf data/animation_presets.conf
```

Setup project and build `animgen` with `meson`:
```
meson setup --buildtype=release build
meson compile -C build animgen
./build/tools/animgen data/animation_presets.conf > src/transition/generated/script_templates.c
```

Build and install with `ninja`:
```
ninja -C build
sudo ninja -C build install
```
