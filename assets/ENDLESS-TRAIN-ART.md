# Раздельные слои для бесконечной поездки

Созданы встроенным ImageGen, сохранены в `C:/Users/user/OneDrive/Documents/последний-трамвай/assets`.

- train-horizon-v2.png — отдельное небо и дальние холмы.
- train-outskirts-layer.png, train-fields-layer.png, train-forest-layer.png — PNG с настоящей прозрачностью вместо неба. Размер всех файлов 2172×724. Исходные панорамы сохранены.

В Godot небо, местность и ближний план двигаются отдельно; участки местности принадлежат одной мировой ленте и переразмещаются за пределами окна.

## horizon

Use case: stylized-concept. Asset type: seamless far-background layer for a hand-painted semi-pixel autumn horror game seen through a moving train window. Extra wide 3:1 panoramic 3072x1024. ONLY a quiet olive-grey evening sky with softly broken layered clouds, faint warm desaturated ochre glow very low on horizon, distant softly outlined dark moss hills occupying bottom 15 percent. No buildings, no trees in foreground, no poles, no railway, no people, no text. Horizon at 75% height. The left and right edges must join seamlessly for horizontal looping, no prominent central sun, very even cloud texture all along the strip. Rough pixel-painterly brush marks, not smooth vector, not 3D, restrained charcoal sage olive mustard palette. This layer moves much slower than buildings in front, so no middle-distance objects.

## outskirts

Use case: background-extraction. Edit target: this exact 2172x724 outskirts panorama, used as a scrolling middle-distance game layer. Remove ONLY the sky and distant skyline backdrop, replacing them with genuine transparent alpha. Preserve all town buildings, chimneys, roofs, fences, birches and their thin branches pixel-for-pixel in their original positions, colors and rough semi-pixel hand-painted style. The entire lower ground region must stay fully opaque. Preserve the original 3:1 image size and full panorama with no margins, no crop, no shifting. The sky down to the roof/tree/ground silhouette must be transparent. Remove very distant hills as sky backdrop; keep foreground and all identifiable structures and trees. No new background, no checkerboard pattern, no new painting, no text. Output transparent PNG. This will be composited over a separately moving distant sky, and must retain exact artwork continuity.

## fields

Use case: background-extraction. Edit target: this exact 2172x724 fields panorama, used as a scrolling middle-distance game layer. Remove ONLY the sky and distant skyline backdrop, replacing them with genuine transparent alpha. Preserve all fields, ditch, house, close shrubs, and the row of distant birch trees pixel-for-pixel in their original positions, colors and rough semi-pixel hand-painted style. The entire lower ground region must stay fully opaque. Preserve the original 3:1 image size and full panorama with no margins, no crop, no shifting. The sky down to the roof/tree/ground silhouette must be transparent. Remove very distant hills as sky backdrop; keep foreground and all identifiable structures and trees. No new background, no checkerboard pattern, no new painting, no text. Output transparent PNG. This will be composited over a separately moving distant sky, and must retain exact artwork continuity.

## forest

Use case: background-extraction. Edit target: this exact 2172x724 forest panorama, used as a scrolling middle-distance game layer. Remove ONLY the sky and distant skyline backdrop, replacing them with genuine transparent alpha. Preserve all forest birch and pine trunks, fine branches and remaining leaves, lower foliage and grasses pixel-for-pixel in their original positions, colors and rough semi-pixel hand-painted style. The entire lower ground region must stay fully opaque. Preserve the original 3:1 image size and full panorama with no margins, no crop, no shifting. All visible sky openings between branches and tree trunks, including gaps down to the distant forest silhouette, should be transparent; preserve dark tree masses as foreground. No new background, no checkerboard pattern, no new painting, no text. Output transparent PNG. This will be composited over a separately moving distant sky, and must retain exact artwork continuity.

