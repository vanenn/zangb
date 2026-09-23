# 美术生成记录

以下四份素材均使用内置 imagegen 工具生成，未使用 API/CLI 备用方案。生成结果复制到项目 `assets/`，源图未删除。图集保持原图，运行时按格读取。

## 人物图集：assets/characters.png

原始文件：`exec-6b1d4343-bcb1-46c6-90c4-6e5a67c725c2.png`。

```text
Use case: stylized-concept. Create a production game sprite atlas for an original Chinese zombie survivors game, gloomy horror storybook style: broken charcoal outlines, dirty gray-green watercolor washes, muted rust red, detailed hand-painted silhouettes on a GENUINELY TRANSPARENT background. Square 2048x2048 image. EXACT 4 by 4 uniform grid, each cell 512x512, one full body standing character centered per cell with feet at cell y=445, all entire bodies fully inside cells with generous transparent margins. No text, labels, borders, scenery, floor or shadows. Orthographic front three-quarter view suitable for top-down 2D action game, large heads, readable shapes. Row 1 left to right: female schoolteacher in long brown cardigan holding books; male mechanic in dirty green overalls holding wrench; female security guard in dark navy uniform with baton; female chemistry teacher white lab coat holding flaming bottle. Row 2: male nail-gun repairman with yellow hardhat; male shotgun security officer; female nurse with medical bag and small pistol; stocky chef with cleaver and apron. Row 3: young adult courier with orange jacket backpack and brick; thin shambling gray zombie in torn suit; fast hunched infected runner; screaming infected with huge open mouth. Row 4: bloated acid-spitter zombie; armored riot-gear zombie; zombie pushing a broken shopping cart; enormous zombie school bell-ringer with dangling brass bells. All characters are ADULTS. Horror, weary humanity, not cute, not vector, not 3D, no pixel art. Maintain consistent scale and linework across all cells, readable silhouettes at 60 pixels tall. This is final in-game art, not a mockup.
```

工具实际返回1254×1254图像，项目按实际尺寸划分4×4图集，不依赖提示词中的尺寸。

## 标题插画：assets/cover.png

原始文件：`exec-41f47b5f-61d5-4db5-b6ff-e79a1fad504e.png`。

```text
Use case: illustration-story. Final background painting for title screen of original gloomy zombie survival game '灰城余生' (do NOT render text). Wide landscape 16:9, hand painted horror storybook: broken charcoal contours, gray green watercolor, dirty ivory paper grain, desaturated ochre window lights, tiny rust-red accents. A rain-drenched abandoned Chinese neighborhood at night: old middle school building and gate on left, empty street disappearing into mist centrally, decaying shopping mall on right; silhouettes of abandoned bicycles, fallen notice papers, a few distant infected silhouettes. Lower right foreground has a small weary group of ADULT survivors seen from behind (teacher holding book, mechanic, nurse, security guard) sheltering under a torn awning, facing the city. Composition: left half upper-mid is atmospheric dark negative space suitable for large cream Chinese game title and menu overlays; most detailed architecture and figures on right. Beautiful traditional watercolor editorial illustration, tactile haunted illustrated book aesthetic, cinematic but restrained, not photograph, not 3D, not cartoon, not pixel art, no text or logo or UI. Strong readable values, subtle fog, not entirely black.
```

## 场景物件：assets/props.png

原始文件：`exec-ce2464f3-b5d4-44d8-b810-869da5e05947.png`。

```text
Use case: stylized-concept. Production environment prop atlas for a top-down 2D zombie survival game with charcoal outlines, desaturated gray-green watercolor, dirty ivory paper texture, faint rust-red marks, gloomy illustrated horror book aesthetic. Square image, EXACT 4 by 4 equal grid. Each cell contains ONE completely isolated environment object, fully contained in its cell with 12% empty transparent margins; GENUINELY TRANSPARENT background, no floor, no contact shadows, no labels, text, borders, grid lines or scenery. Orthographic overhead three-quarter view (see tops and fronts), consistent game perspective. Row 1: cluster of three abandoned wooden school desks; tall dented metal school lockers; wheeled cracked blackboard with subtle illegible chalk scratches; dusty library bookshelf. Row 2: abandoned moss-green sedan seen from above; ruined off-white delivery van seen from above; concrete street barricade with peeling warning paint; bent streetlamp. Row 3: broken mall display counter; shop clothes racks covered in tatters; dry circular mall fountain; abandoned retail shelving unit. Row 4: open wooden supply crate holding canned food and bandages; red-cross medical satchel; scattered soggy papers and books; fallen cracked shop sign with illegible faded shapes. Fine handmade charcoal detail with uneven outlines and watercolor staining, readable silhouettes at small game size. Not vector, not pixel art, not 3D render. No people or zombies.
```

## 地面纹理：assets/floors.png

原始文件：`exec-b4d2cc15-7cd5-4ecf-9d35-ee1f91152f6d.png`。

```text
Use case: stylized-concept. Make a square 2x2 game ground texture atlas, four EXACT equal square quadrants, viewed STRICTLY top down orthographic, no perspective, no objects, no text, no borders, no UI, opaque image. Designed as subtle repeating floor tiles behind characters in a gloomy charcoal and watercolor horror storybook game. Top left quadrant: worn gray-olive school linoleum, extremely subtle seams, powdered chalk smudges, graphite scrapes, old papery grain. Top right quadrant: dark gray-green rain soaked asphalt, subtle watercolor pooling, cracks and gritty paper texture; NO road markings. Bottom left quadrant: dirty gray-beige shopping mall stone floor, large faint square tile seams, irregular watercolor grime. Bottom right quadrant: aged desaturated olive-gray paper with fine charcoal grain and mottled watercolor washes, abstract texture. Each quadrant is a complete usable tileable texture with consistent medium dark tonal value within itself, edges match for repeating. Tactile ink and watercolor, hand painted, restrained contrast to keep small dark zombie characters visible. No detailed debris, no bright spots, no colorful areas, no realistic photo or 3D render.
```


## 第二版人物图集：assets/characters-v2.png

内置 imagegen 生成，再以同一工具清理背景与越界特效。原始生成文件为 `exec-8089d365-b5e6-430f-a6e4-8e548994d8e5.png`，最终编辑文件为 `exec-f82219e5-a481-4e0e-ae56-abd4e003e79a.png`。最终图像原样复制，未使用脚本抠图。

图集为3列2行：电工、化工、消防员；猎人、音响师、环卫工。Godot 按实际尺寸切分为六个 AtlasTexture，接在原图集编号16—21之后。已读取像素确认具有透明 Alpha，并在整备、名册和战斗画面检查透明背景。

最终编辑提示词：

```text
Edit this six-character 3-column 2-row game sprite atlas. Remove ALL background including dark gradients, haze, glows, cast shadows, ground. Output genuine transparent RGBA alpha everywhere outside the six characters and their held equipment. Preserve the six illustrated characters exactly with the same positions and 3 by 2 equal cell layout. Remove spray/electrical/acid effects extending beyond held equipment so nothing crosses cell boundaries. Each figure and equipment must be fully inside its own cell with clear transparent margins; slightly shrink the figures uniformly if needed to ensure margins. Do not change character design or illustration style. This must be a clean transparent sprite sheet usable over a game floor, not a background painting.
```

角色服装、装备与旧图集保持炭笔和水彩方向。电弧、喷流、抛物线、书本旋转、定向挥击与电锯工作/过热反馈由运行时代码绘制；这些不是额外的逐帧动画素材。
