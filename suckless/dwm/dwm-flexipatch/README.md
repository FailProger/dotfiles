DWM INSTALLATION
---

## Warning
It is not official repo. It is my dwm configuration base on `bakkeby/dwm-flexipatch`.

For about `dwm-flexipatch` more see author: `https://github.com/bakkeby/dwm-flexipatch`.

## How install
1. Clone and patch `dwm-flexipatch` (**NOT** `dwm`)
2. First patch `my-patches.diff`
3. Next copy `patches.def.h` to `patches.h` and patch `patches.h.diff`
4. Copy `config.h`
5. Finalize and make

### Step by step
Clone repo:
```
git clone --depth 1 'https://github.com/FailProger/dotfiles'
cd dotfiles/suckless/dwm/dwm-flexipatch
```

Clone `dwm-flexipatch` and patch:
```
git clone --depth 1 'https://github.com/bakkeby/dwm-flexipatch'
cd dwm-flexipatch
patch -p1 < ../my-patches.diff
cp patches.def.h patches.h
patch -p1 < ../patches.h.diff
cp ../config-laptop.h config.h
cd ..
```

Finalize dwm before make:
```
git clone --depth 1 'https://github.com/bakkeby/flexipatch-finalizer'
cd flexipatch-finalizer
./flexipatch-finalizer -d ../dwm-flexipatch -o ../fin --run
cd ..
```

Make:
```
cd fin
make
sudo make install
```

## Themes
There are two `config.h` files:
1. `config-laptop.h`
2. `config-desktop.h`

### Laptop theme (`config-laptop.h`)
Theme with white accent color and without windows paddings and without borders for taling widnows.

After patching and finalizing you can copy `config-laptop.h` and make `dwm` without any source edits.

### Desktop theme (`config-desktop.h`)
Theme with red accent color and with windows paddings and with borders for all widnows.

After patching and finalizing you can copy `config-desktop.h` and make `dwm` without any source edits.
