# Layered visionOS icon source

28 October 2026. Source artwork and target registration are published toward
the active all-project goal. Native compilation and distribution remain open.

The repo previously had bundle metadata and a privacy manifest but no asset
catalog. Three original SVG masters now describe an ivory board with two
colored nodes and a connector over a full-square teal background. The shapes
remain centered for the system's circular mask. No outer mask, text, baked
shadow or external image is included.

The standard-library [exporter](../../../../script/render_app_icon.py) writes
1024-square sRGB PNGs: opaque RGB Back, transparent RGBA Middle/Front, and an
[unmasked flat artwork reference](../../../../artwork/app-icon/Preview.png).
The reference is not an actual visionOS rendering or parallax acceptance.
`--check` compares format and decoded image data rather than platform-specific
zlib compression bytes. No image-model call or external dependency was used.

## Primary format evidence

Apple's [configuration guide](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
and [app-icon HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons)
describe layered visionOS icons, square 1024-pixel source, upper-layer alpha and
system circular masking. Exact catalog structure follows Apple's Xcode 16 /
visionOS 2 [Creating 2D shapes with SwiftUI sample](https://developer.apple.com/documentation/visionos/creating-2d-shapes-in-visionos-with-swiftui).

The [official sample ZIP](https://docs-assets.developer.apple.com/published/5d97d949da4b/Creating2DShapesInVisionOSWithSwiftUI.zip)
is 45,602 bytes, SHA256
`a1c1067bab7ddb263f004fdbb6e5d37cbcbf4f61dd5da2c683672d6f63a73252`.
Its `AppIcon.solidimagestack` lists Front, Middle, Back layers. Each
`.solidimagestacklayer` contains a `Content.imageset` using `idiom: vision`,
`scale: 2x` and no platform key. Our eight catalog JSON files match the sample
after adding only the three original PNG filename fields.

The target's Resources phase includes the catalog and Debug/Release select
`AppIcon`. Removing only those new references/settings from parsed project
metadata reproduces the prior project exactly, including signing, deployment
target and device family. App/core/test/package/helper/CI source is unchanged.

## Checks and limits

SVG export and `--check`, project plist lint and whitespace checks passed.
The flat artwork and transparent foreground were inspected directly. Independent
PNG checks verified chunk checksums, decompression size, sRGB metadata, 1024-square
RGB/RGBA formats, transparent/opaque/antialiased foreground pixels and expected
background/board/node colors. `sips` independently reports the dimensions,
RGB space and intended alpha channels. All eight catalog JSON structures were
compared directly with the official ZIP; all 20 owned files passed whitespace
checks and ten local documentation targets resolve. Independent source review
found no blocker in alpha compositing, catalog paths or target registration.

| Export | Bytes | SHA256 |
| --- | --- | --- |
| Back | 4,569 | `a9f00875f72cdafd77440a41abda5979fa59462b16df9c6dcd9e9f12c62f2999` |
| Middle | 6,943 | `80d3341d0a373d3cfcfbbe0ba963e5864d840a709e45cf9d15e512b74fa95aa9` |
| Front | 6,095 | `8e51168cad0dee18e3e5c069d8946c41b649afee60ad7b4511b13dda3dbf321f` |
| Flat artwork reference | 8,494 | `906dd731eb414e58867fd779218c3d389eeae4db29b715ffee2fcb42eb72d5ee` |

Exporter SHA256:
`4bdba536a16700b77acfdaabbd41cfbb268c2bdbc5feaa17e3a68c9e69d1185e`.
Project SHA256:
`b10b9eb593b44e47c90ad66510f234f0076d74ed74ae647a9baf47e40276f8c9`.
The two task-owned Apple sample downloads were removed after metadata/provenance
capture.

No native core tests, asset compiler, app build, simulator boot, app launch,
eye/hand input, notification prompt, signing, store submission or CI dispatch
ran. Standard Xcode and Xcode-beta application paths were absent; that is not
an exhaustive installation search. The existing [native-check proposal](../../../proposals/native-checks.md)
remains pending approval. Source metadata proves neither `actool` acceptance
nor the icon's depth, scale or appearance on a simulator/device. The exact
“TL;DW” reference in the brief also remains an open product clarification.

## Publication

Source [`1b8d2f5761fa2cd816a56148a4430d703b60eec7`](https://github.com/alvarovillalbaa/spatial-whiteboard/commit/1b8d2f5761fa2cd816a56148a4430d703b60eec7)
was pushed to personal-repository main. Immutable connected GitHub reads match
the local project (`ee022e228e97e92abfe6e4e6780e09e0eca186c5`), exporter
(`fb2dcb3c504776395ae682399627a07f276b9a2b`), stack metadata
(`e6a454635c112b655ac282b18fdea68fe4af90fe`) and all three PNG blobs. Remote
main matched that source exactly. The later receipt-only commit preserves
all checked artwork, resource/project and app/core/test bytes. No active
workflow or hosted service was introduced; native-check approval is pending.
