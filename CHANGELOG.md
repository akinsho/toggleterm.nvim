# Changelog

## [2.8.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.7.1...v2.8.0) (2023-09-11)


### Features

* add `Terminal.find` function ([#486](https://github.com/akinsho/toggleterm.nvim/issues/486)) ([01a84bc](https://github.com/akinsho/toggleterm.nvim/commit/01a84bc642484681933140537c3ff99b10b8a866))
* add name param to ToggleTerm and TermExec ([#479](https://github.com/akinsho/toggleterm.nvim/issues/479)) ([81ea9f7](https://github.com/akinsho/toggleterm.nvim/commit/81ea9f71a3fd7621fd02b2c74861595378a3c938))


### Bug Fixes

* **#487:** avoid terminal id collisions in __add ([#490](https://github.com/akinsho/toggleterm.nvim/issues/490)) ([6bec54e](https://github.com/akinsho/toggleterm.nvim/commit/6bec54e73807919b15fc92824fb48be32fb7e8ea))
* determine custom terminal ids on spawn ([#488](https://github.com/akinsho/toggleterm.nvim/issues/488)) ([8572917](https://github.com/akinsho/toggleterm.nvim/commit/8572917413dd039d1a53b007df5c571e2a3b8ad7))
* TermExec cmd with config.shell as function ([#467](https://github.com/akinsho/toggleterm.nvim/issues/467)) ([83871e3](https://github.com/akinsho/toggleterm.nvim/commit/83871e3c34837117644d83f422ee6c869b61891f))


### Reverts

* determine custom terminal ids on spawn ([#488](https://github.com/akinsho/toggleterm.nvim/issues/488)) ([0e4dcb8](https://github.com/akinsho/toggleterm.nvim/commit/0e4dcb8f0914bd191f732cae826df59f174359fe))

## [2.7.1](https://github.com/akinsho/toggleterm.nvim/compare/v2.7.0...v2.7.1) (2023-07-10)


### Bug Fixes

* handle errors when switching buffer [#453](https://github.com/akinsho/toggleterm.nvim/issues/453) ([#454](https://github.com/akinsho/toggleterm.nvim/issues/454)) ([029ad96](https://github.com/akinsho/toggleterm.nvim/commit/029ad968fd5a06ac5e29afe083d0a61be68e792b))
* replace vim.wo with nvim_set_option_value ([#449](https://github.com/akinsho/toggleterm.nvim/issues/449)) ([7da102a](https://github.com/akinsho/toggleterm.nvim/commit/7da102a9c2fa1dd190c11faea03ee1c47af03d02))
* **terminal:** allow resizing hidden terminals ([bacbaa7](https://github.com/akinsho/toggleterm.nvim/commit/bacbaa7480344e4cfcebdf46fdfc058b3cb04648)), closes [#459](https://github.com/akinsho/toggleterm.nvim/issues/459)

## [2.7.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.6.0...v2.7.0) (2023-05-22)


### Features

* add a terminal select command ([#429](https://github.com/akinsho/toggleterm.nvim/issues/429)) ([c8574d7](https://github.com/akinsho/toggleterm.nvim/commit/c8574d7a7d2e5682de4479463ddba794390c0e40))
* allow changing terminal dir in background ([#438](https://github.com/akinsho/toggleterm.nvim/issues/438)) ([f5cf0b1](https://github.com/akinsho/toggleterm.nvim/commit/f5cf0b1eebd95ba4edc69e2fbd13e1a289048d5d))


### Bug Fixes

* **float:** ensure sidescroll is zero ([43b75f4](https://github.com/akinsho/toggleterm.nvim/commit/43b75f43aa7590228d88945525c737f0ddc05c22))

## [2.6.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.5.0...v2.6.0) (2023-04-09)


### Features

* **config:** allow `shell` parameter to be a function ([#423](https://github.com/akinsho/toggleterm.nvim/issues/423)) ([a7857b6](https://github.com/akinsho/toggleterm.nvim/commit/a7857b6cbfdfc98df2a7b61591be16e1020c7a82))

## [2.5.0](https://github.com/akinsho/toggleterm.nvim/compare/2.4.0...v2.5.0) (2023-03-31)


### ⚠ BREAKING CHANGES

* switch persist_mode to false ([#410](https://github.com/akinsho/toggleterm.nvim/issues/410))

### Features

* support z-index option for floating windows ([#418](https://github.com/akinsho/toggleterm.nvim/issues/418)) ([0aa9364](https://github.com/akinsho/toggleterm.nvim/commit/0aa936445b895cd5d3387860f96ce424ce32b072))
* switch persist_mode to false ([#410](https://github.com/akinsho/toggleterm.nvim/issues/410)) ([98e15df](https://github.com/akinsho/toggleterm.nvim/commit/98e15df2c838fe5c3cae1efa36fa5c255fc75aa8))
* **terminal:** add mechanism to fetch last focused terminal ([#411](https://github.com/akinsho/toggleterm.nvim/issues/411)) ([bfb7a72](https://github.com/akinsho/toggleterm.nvim/commit/bfb7a7254b5d897a5b889484c6a5142951a18b29))


### Miscellaneous Chores

* release 2.5.0 ([f14cbfd](https://github.com/akinsho/toggleterm.nvim/commit/f14cbfd3141ce35d2738084e40bccf2176a474b2))
