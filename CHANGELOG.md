# Changelog

## [0.2.0](https://github.com/bottrall/bearings/compare/v0.1.0...v0.2.0) (2026-11-28)


### ⚠ BREAKING CHANGES

* a manifest that sets checks.external_links now gets a manifest problem for an unknown key. Delete the key; run rake docs:check:external to check external links.

### Features

* let templates share markup through partials ([#69](https://github.com/bottrall/bearings/issues/69)) ([9155b51](https://github.com/bottrall/bearings/commit/9155b515706df7a614e09bbfe72f2b36627b5862)), closes [#60](https://github.com/bottrall/bearings/issues/60)
* remove checks.external_links from the manifest ([#66](https://github.com/bottrall/bearings/issues/66)) ([f56d2c9](https://github.com/bottrall/bearings/commit/f56d2c9378768b6c45905d465688f886b352041c)), closes [#63](https://github.com/bottrall/bearings/issues/63)
* render 404.html.erb as the 404 page, with the landing page's values ([#68](https://github.com/bottrall/bearings/issues/68)) ([f7cdbe9](https://github.com/bottrall/bearings/commit/f7cdbe97754319e72ec5074f2555ecc45b2fb284)), closes [#59](https://github.com/bottrall/bearings/issues/59)
* wrap every code block and name its language in an attribute ([#67](https://github.com/bottrall/bearings/issues/67)) ([6f2c85a](https://github.com/bottrall/bearings/commit/6f2c85a26208fb49db283c5365abe7286abc6474)), closes [#61](https://github.com/bottrall/bearings/issues/61)

## 0.1.0 (2026-11-24)


### Features

* add OutputFile value and the writer that puts files in _site ([#29](https://github.com/bottrall/bearings/issues/29)) ([a258f1f](https://github.com/bottrall/bearings/commit/a258f1f0086a73209fb42e8e9583edf66698ad0a)), closes [#6](https://github.com/bottrall/bearings/issues/6)
* add Problem value with text and JSON reports ([#27](https://github.com/bottrall/bearings/issues/27)) ([8ab2a29](https://github.com/bottrall/bearings/commit/8ab2a296ab96b27fd39d788b94cd58721ddae9f7)), closes [#2](https://github.com/bottrall/bearings/issues/2)
* build and check bearings' own guides with bearings ([#54](https://github.com/bottrall/bearings/issues/54)) ([de934e7](https://github.com/bottrall/bearings/commit/de934e767fa6d6f7a8a8b10d8fed06a2e10e962d))
* build the site model from the manifest, files and a renderer ([#34](https://github.com/bottrall/bearings/issues/34)) ([0dd570b](https://github.com/bottrall/bearings/commit/0dd570be385893ac9d17464b120c7aa64069925d)), closes [#5](https://github.com/bottrall/bearings/issues/5)
* build the site with rake docs and check it with rake docs:check ([#47](https://github.com/bottrall/bearings/issues/47)) ([82510be](https://github.com/bottrall/bearings/commit/82510beec84ef56aaa088b17ee6a5be255f3d664)), closes [#23](https://github.com/bottrall/bearings/issues/23)
* check external links in an opt-in docs:check:external task ([#43](https://github.com/bottrall/bearings/issues/43)) ([2e78267](https://github.com/bottrall/bearings/commit/2e78267818c5315b238b6525b0112f64e1513e5c))
* check images are present, described, small enough and used ([#51](https://github.com/bottrall/bearings/issues/51)) ([61aaef5](https://github.com/bottrall/bearings/commit/61aaef54ffb4b437da9bd13d28769b265f5c97e1)), closes [#20](https://github.com/bottrall/bearings/issues/20)
* check that each mermaid diagram names a known type and has a title ([#50](https://github.com/bottrall/bearings/issues/50)) ([09bbaae](https://github.com/bottrall/bearings/commit/09bbaae09d5a03cbb2a9defc94605ff5a0b82df5)), closes [#21](https://github.com/bottrall/bearings/issues/21)
* check that every internal link and anchor resolves, in every output ([#52](https://github.com/bottrall/bearings/issues/52)) ([9ba6e98](https://github.com/bottrall/bearings/commit/9ba6e9890767cc3cea59ebc99e89936e2bbeef15)), closes [#17](https://github.com/bottrall/bearings/issues/17)
* check that ruby, json and yaml examples parse ([#41](https://github.com/bottrall/bearings/issues/41)) ([0bf77bc](https://github.com/bottrall/bearings/commit/0bf77bc388f688e24ff607dfb28563c569591d26))
* check the manifest matches disk ([#36](https://github.com/bottrall/bearings/issues/36)) ([ab06e71](https://github.com/bottrall/bearings/commit/ab06e7152587c2844a3aaea2453c1040b26638b7)), closes [#16](https://github.com/bottrall/bearings/issues/16)
* copy the images guides use into /assets with width and height ([#49](https://github.com/bottrall/bearings/issues/49)) ([67aaede](https://github.com/bottrall/bearings/commit/67aaede34c1d12ff0bd5737cb855bc2fce0e7851))
* load and validate the manifest ([#30](https://github.com/bottrall/bearings/issues/30)) ([bfeb1c8](https://github.com/bottrall/bearings/commit/bfeb1c8a1451db378e6cd6133f341a0cb96b8d50)), closes [#3](https://github.com/bottrall/bearings/issues/3)
* mark mermaid fences as diagrams and let a renderer draw them ([#48](https://github.com/bottrall/bearings/issues/48)) ([b006794](https://github.com/bottrall/bearings/commit/b006794c950275be5397a010ab72c2163dd229ab)), closes [#15](https://github.com/bottrall/bearings/issues/15)
* parse a guide into a Document and render its body ([#31](https://github.com/bottrall/bearings/issues/31)) ([3f18f44](https://github.com/bottrall/bearings/commit/3f18f44f2cc22841f5270505b751d71e937f6b2a)), closes [#4](https://github.com/bottrall/bearings/issues/4)
* render each guide through the repo's own layout ([#44](https://github.com/bottrall/bearings/issues/44)) ([0119c18](https://github.com/bottrall/bearings/commit/0119c188fcd035271bc60954d4142fa2730e17f2)), closes [#7](https://github.com/bottrall/bearings/issues/7)
* render GitHub alert blocks as labelled notes ([#32](https://github.com/bottrall/bearings/issues/32)) ([3164722](https://github.com/bottrall/bearings/commit/3164722722061ea5bb13c790e577c7c828aa7f18)), closes [#13](https://github.com/bottrall/bearings/issues/13)
* report project constants a guide names that sig/ does not declare ([#42](https://github.com/bottrall/bearings/issues/42)) ([ff65cca](https://github.com/bottrall/bearings/commit/ff65cca75f73bda1197ed280d3bbcb594b912910))
* serve _site/ and rebuild on change with rake docs:serve ([#53](https://github.com/bottrall/bearings/issues/53)) ([5f9a085](https://github.com/bottrall/bearings/commit/5f9a0855d19d95158959ffb8f7ce7928753444c8))
* write a markdown copy of every guide at /guides/&lt;slug&gt;.md ([#45](https://github.com/bottrall/bearings/issues/45)) ([6d9b7aa](https://github.com/bottrall/bearings/commit/6d9b7aae50a1dc8287044dfc9e75f66d67c6db90))
* write llms.txt and llms-full.txt from the site model ([#46](https://github.com/bottrall/bearings/issues/46)) ([f5eef5c](https://github.com/bottrall/bearings/commit/f5eef5cf7babdab63caef3438fe9fda52b94ad83))
* write redirect stubs from the manifest and check their targets ([#37](https://github.com/bottrall/bearings/issues/37)) ([a982041](https://github.com/bottrall/bearings/commit/a9820417196cfc8bbd14a3ba7659cbb31a9ebd87)), closes [#12](https://github.com/bottrall/bearings/issues/12)
* write search.json with an entry per section ([#38](https://github.com/bottrall/bearings/issues/38)) ([28be1d1](https://github.com/bottrall/bearings/commit/28be1d1d2a87685be160b69f026e007d4490897c))
* write sitemap.xml and robots.txt from the site model ([#35](https://github.com/bottrall/bearings/issues/35)) ([bfb3821](https://github.com/bottrall/bearings/commit/bfb38218d47555dc3a99afca438b881d6fbb6752))
