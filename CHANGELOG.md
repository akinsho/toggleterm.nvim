# Changelog

## [2.13.1](https://github.com/akinsho/toggleterm.nvim/compare/v2.13.0...v2.13.1) (2024-12-27)


### Bug Fixes

* check for terminal win before check if is valid ([#622](https://github.com/akinsho/toggleterm.nvim/issues/622)) ([22aefd4](https://github.com/akinsho/toggleterm.nvim/commit/22aefd4445570ae2a0145aeeb6388caa88dfd7af)), closes [#435](https://github.com/akinsho/toggleterm.nvim/issues/435)

## [2.13.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.12.0...v2.13.0) (2024-11-01)


### Features

* add clear_env option ([#598](https://github.com/akinsho/toggleterm.nvim/issues/598)) ([16a2873](https://github.com/akinsho/toggleterm.nvim/commit/16a2873e674b17b67a399db657c359e0a0c906ff))
* add responsive capabilities for horizontal direction ([#618](https://github.com/akinsho/toggleterm.nvim/issues/618)) ([db7607c](https://github.com/akinsho/toggleterm.nvim/commit/db7607c436589b395d8a1850e0ae22c8e51a5315))


### Bug Fixes

* set_mode may not be taken into account ([#596](https://github.com/akinsho/toggleterm.nvim/issues/596)) ([137d06f](https://github.com/akinsho/toggleterm.nvim/commit/137d06fb103952a0fb567882bb8527e2f92d327d))

## [2.12.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.11.0...v2.12.0) (2024-06-25)


### Features

* add shading_ratio option ([#580](https://github.com/akinsho/toggleterm.nvim/issues/580)) ([74ce690](https://github.com/akinsho/toggleterm.nvim/commit/74ce6904e10e9bf2b7ffde598afc106c1d61e59c))

## [2.11.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.10.0...v2.11.0) (2024-04-22)


### Features

* add string array support to `open_mapping` setting. ([#557](https://github.com/akinsho/toggleterm.nvim/issues/557)) ([5ec59c3](https://github.com/akinsho/toggleterm.nvim/commit/5ec59c3a8ae4f220e40f0d37e1732354ee3ba181))
* support the CR for nushell ([#561](https://github.com/akinsho/toggleterm.nvim/issues/561)) ([72d2aa2](https://github.com/akinsho/toggleterm.nvim/commit/72d2aa290a8bcd3155d851b3d7a28ea20a1dc1f1))


### Bug Fixes

* autochdir for custom terminals ([#553](https://github.com/akinsho/toggleterm.nvim/issues/553)) ([dca1c80](https://github.com/akinsho/toggleterm.nvim/commit/dca1c80fb8ec41c97e7c3ef308719d8143fbbb05))
* clear command ([#565](https://github.com/akinsho/toggleterm.nvim/issues/565)) ([fef08f3](https://github.com/akinsho/toggleterm.nvim/commit/fef08f32b9ca7d08eefc5af34dc416a3ac259bc8))
* cmd and path now work with paths containing spaces ([#483](https://github.com/akinsho/toggleterm.nvim/issues/483)) ([f059a52](https://github.com/akinsho/toggleterm.nvim/commit/f059a52c3f8adb285cff66882462f67603c1f9ba))
* column indexing ([#572](https://github.com/akinsho/toggleterm.nvim/issues/572)) ([9e65d60](https://github.com/akinsho/toggleterm.nvim/commit/9e65d60cfa0c33a9ddc9cc9ec77471753f1984df))
* cursor position after motion ([#563](https://github.com/akinsho/toggleterm.nvim/issues/563)) ([75d3de9](https://github.com/akinsho/toggleterm.nvim/commit/75d3de9d261431dd4d6a68134bb46907c91c2023))
* ensure `on_choice` operates on exact `items` element ([#566](https://github.com/akinsho/toggleterm.nvim/issues/566)) ([d3fff44](https://github.com/akinsho/toggleterm.nvim/commit/d3fff44252b57da0dc918b5eb7aeee258603a2a7))

## [2.10.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.9.0...v2.10.0) (2024-02-12)


### Features

* enable title for floating terminals ([#534](https://github.com/akinsho/toggleterm.nvim/issues/534)) ([d3aa6e8](https://github.com/akinsho/toggleterm.nvim/commit/d3aa6e88c2dcbefd240ffb77a2c77b486a19fa5f))


### Bug Fixes

* send_lines_to_terminal now honours ID variable when trim_spaces = false ([#541](https://github.com/akinsho/toggleterm.nvim/issues/541)) ([63ac4c8](https://github.com/akinsho/toggleterm.nvim/commit/63ac4c8529604ad247d9426644128de6ebb1f43a))

## [2.9.0](https://github.com/akinsho/toggleterm.nvim/compare/v2.8.0...v2.9.0) (2023-12-06)


### Features

* allow operator mapping to send to terminal ([#507](https://github.com/akinsho/toggleterm.nvim/issues/507)) ([5b84866](https://github.com/akinsho/toggleterm.nvim/commit/5b848664989b6deb2c28dad5135c89720915675a))


### Bug Fixes

* **commands:** call ToggleTermSetName with count ([#497](https://github.com/akinsho/toggleterm.nvim/issues/497)) ([ef1bbff](https://github.com/akinsho/toggleterm.nvim/commit/ef1bbff59c9ab5b468062c33ca183541a3849547)), closes [#496](https://github.com/akinsho/toggleterm.nvim/issues/496)
* **terminal:** clear correctly on windows ([#513](https://github.com/akinsho/toggleterm.nvim/issues/513)) ([0731e99](https://github.com/akinsho/toggleterm.nvim/commit/0731e99de590fb7451eb4fee99470506e012b34d))

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
