# BottomBar 通用底部导航栏

配置驱动的底部导航栏组件。按钮数量、文案、图标、配色、选中态表现全部可配，**不需要改代码**。

- 组件：`home/BottomBar.tscn` + `home/BottomBar.gd`（容器）
- 单个按钮：`home/BottomTabButton.gd`（支持贴图 + 纯代码绘制回退）
- 宿主页面：`home/Home.tscn` + `home/Home.gd`（通用导航状态与页面调度）
- 双按钮示例：`home/home2.tscn` + `home/Home2.gd`（只提供配置，复用同一套组件）

## 按钮数量

按钮数量 = `tab_configs` 的条数，加几个就有几个。少于 3 个时会自动均分（例如 2 个按钮各占一半）。

`Home.tscn` 的 `demo_preset` 提供两套内置演示：

| 值 | 说明 |
| --- | --- |
| `TWO_TABS`（默认） | 2 个按钮：闯关 / 更多 |
| `FIVE_TABS` | 5 个按钮：基地 / 英雄 / 战役 / 活动 / 商店 |

独立的 `home2.tscn` 是另一套双按钮示例（探索 / 背包），两个按钮各自使用不同的选中动画组合。

## 选中态模式

`selection_mode` 是**位标志**，可以任意组合：

| 常量 | 值 | 效果 |
| --- | --- | --- |
| `SelectionMode.WIDEN` | 1 | 仅横向变宽（默认） |
| `SelectionMode.WIDEN_GROW` | 2 | 变宽 + 向上变高 |
| `SelectionMode.SWAP_ICON` | 4 | 选中时切换图标 |
| `SelectionMode.ICON_SCALE` | 8 | 选中时图标放大（倍率可配） |
| `SelectionMode.ICON_LIFT` | 16 | 图标放大并上移；取消选中时缩小下移回按钮居中位置 |

组合示例（在检查器里就是个多选下拉框）：

- 默认：`1` — 只变宽
- 变宽 + 变高：`3`（`WIDEN | WIDEN_GROW`）
- 变宽 + 换图 + 放大：`13`（`WIDEN | SWAP_ICON | ICON_SCALE`）
- 变宽 + 图标放大上移：`17`（`WIDEN | ICON_LIFT`）
- 五种全开：`31`（`WIDEN | WIDEN_GROW | SWAP_ICON | ICON_SCALE | ICON_LIFT`）

> 注意 `WIDEN_GROW` 本身已包含变宽效果，单独用 `2` 与 `3` 视觉一致；写 `3` 语义更清楚。

### 每个按钮单独指定效果

容器级 `selection_mode` 是默认值；某个 Tab 的配置里写 `selection_mode` 即可覆盖它，
因此同一个 BottomBar 中不同按钮可以有不同动画。传 `-1`（或不写）表示跟随容器设置。

运行时也可以修改：

```gdscript
$BottomBar.set_selection_mode(BottomBar.SelectionMode.WIDEN)
$BottomBar.set_tab_selection_mode(&"bag", BottomBar.SelectionMode.WIDEN_GROW | BottomBar.SelectionMode.SWAP_ICON)
```

## BottomBar 背景

BottomBar 自身可绘制一层背景，按钮叠在它上面。在检查器里选中 BottomBar 节点即可配置：

| 属性 | 说明 |
| --- | --- |
| `background_color` | 纯色底，alpha > 0 时绘制 |
| `background_texture` | 图片底，叠加在纯色之上；可带透明区域透出底色 |
| `background_tile` | 关闭=拉伸铺满，开启=平铺 |
| `background_modulate` | 图片调制色，可整体染色 / 调透明度 |

运行时修改（属性带 setter，赋值后立即重绘）：

```gdscript
$BottomBar.set_background(Color(0.06, 0.12, 0.10, 1))                 # 纯色
$BottomBar.background_texture = load("res://assets/bottombar/btn_yellow.png")
$BottomBar.background_tile = true
$BottomBar.background_modulate = Color(0.35, 1.0, 0.6, 1.0)           # 染色
$BottomBar.set_background(Color(0, 0, 0, 0), null)                    # 移除背景
```

`home2.tscn` 已设了一个演示纯色背景 `Color(0.055, 0.12, 0.105, 1)`。

### 相关参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `selected_weight` | 2.0 | 选中 Tab 的宽度权重 |
| `normal_weight` | 1.0 | 未选中 Tab 的宽度权重 |
| `selected_grow_height` | 26.0 | `WIDEN_GROW` 下选中 Tab 向上生长高度（px） |
| `selected_icon_scale`（单个 Tab） | 1.35 | `ICON_SCALE` 下选中图标的放大倍率 |
| `icon_lift_scale`（单个 Tab） | 1.28 | `ICON_LIFT` 下选中图标的放大倍率 |
| `icon_lift_offset`（单个 Tab） | 18.0 | `ICON_LIFT` 下选中图标上移的像素；取消时回到居中 |
| `bg_inset_x` / `bg_inset_y`（单个 Tab） | 0.0 | 背景绘制的内边距。默认 0，按钮铺满各自区域、相邻无缝；调大可留出缝隙 |
| `patch_trim_left` / `patch_trim_right`（单个 Tab） | 0.0 | 九宫格采样时从源图左右裁掉的像素。设为 7 可去掉贴图自带深色描边 |
| `background_color`（BottomBar） | 透明 | 容器纯色背景，alpha > 0 时绘制 |
| `background_texture`（BottomBar） | null | 容器图片背景，叠加在纯色之上，拉伸或平铺铺满 |
| `background_tile`（BottomBar） | false | 图片背景平铺 / 拉伸切换 |
| `background_modulate`（BottomBar） | 白色 | 图片背景调制色，可染色或调透明度 |
| `transition_duration` | 0.36 | 动画时长（宽度与高度共用） |

> 按钮之间曾有深色缝，原因有两层：
> 1. `bg_inset_x=5` 让每个按钮左右各缩进 5px —— 默认改成 0 后解决。
> 2. 按钮贴图 `btn_grey/btn_yellow` 自身左右各带约 7px 深色描边，九宫格按原尺寸绘制它，
>    相邻两个按钮就是 7+7=14px 深色缝。
>
> 现在 `Home.gd` / `Home2.gd` 里的 `patch_trim_left/right` 都设为 **0**，即保留贴图原始描边；
> 缝隙改由 BottomBar 背景统一衬托（在 BottomBar 节点上设 `background_color` 或 `background_texture`）。
> 如果更希望按钮直接无缝拼接，把单个 Tab 的 `patch_trim_left/right` 设成 `7` 即可裁掉描边。
> 上下描边是立体边框效果，始终保留（不裁）。
>
> 注意：button 按钮会覆盖在 BottomBar 背景之上，所以背景主要从按钮圆角和缝隙里透出；
> 想让背景占满整条底栏，需要在单个 Tab 配置里把 `bg_inset_x/y` 调大，让按钮留出空隙。

## 单个 Tab 配置项

```gdscript
{
    "id": &"campaign",              # 唯一标识，必填
    "label": "闯关",                 # 显示文案
    "icon": "base",                 # 常态图标
    "selected_icon": "planet",      # SWAP_ICON 模式下选中时用的图标
    "selection_mode": 13,           # 可选：覆盖容器级效果；-1/不写表示继承
    "selected_icon_scale": 1.35,    # 可选：ICON_SCALE 的放大倍率
    "icon_lift_scale": 1.32,        # 可选：ICON_LIFT 的放大倍率
    "icon_lift_offset": 22.0,       # 可选：ICON_LIFT 的上移像素

    # 可选贴图：设置后优先于上面的配色 / 代码绘制图标
    "normal_bg_texture": BTN_GREY,       # 未选中（灰色）
    "selected_bg_texture": BTN_YELLOW,   # 选中（黄色）
    "icon_texture": ICON_CHEST,          # 常态前景图标
    "selected_icon_texture": ICON_CHEST, # SWAP_ICON 时可选

    "enabled": true,                # false 则变暗且不可点
    "keep_state": true,             # 离开页面时是否保留状态

    # 配色
    "normal_bg": Color(...),
    "selected_bg": Color(...),
    "normal_icon_color": Color(...),
    "selected_icon_color": Color(...),
    "accent_color": Color(...),

    # 页面（Demo 用，接真实页面时替换）
    "page_scene": DEMO_PAGE_SCENE,
    "page_title": "闯关",
    "subtitle": "...",
    "badge_text": "CAMPAIGN",
    "background_color": Color(...),
    "accent_color_page": Color(...),
    "enter_style": DemoPage.EnterStyle.SCALE,
}
```

### 内置图标风格

`icon` / `selected_icon` 可取值：`base`、`hero`、`planet`、`gift`、`shop`。都是代码绘制的矢量图形，没有贴图文件依赖。

### 项目内置贴图

`assets/bottombar/` 中已放入四个资源，双按钮示例默认使用它们：

| 文件 | 用途 | 配置键 |
| --- | --- | --- |
| `btn_grey.png` | 未选中按钮底图 | `normal_bg_texture` |
| `btn_yellow.png` | 选中按钮底图 | `selected_bg_texture` |
| `icon_chest.png` | 宝箱前景图标 | `icon_texture` |
| `icon_helmet.png` | 头盔前景图标 | `icon_texture` |

按钮底图使用九宫格绘制（边距 `patch_left/right/top/bottom`），横向拉宽时圆角不会变形。
贴图图标会按 `icon_max_width` / `icon_max_height` 等比缩放。

## 接入真实页面

```gdscript
# 在 Home.tscn 里填 tab_configs，每项的 page_scene 指向你的场景。
# 页面场景根节点必须继承 HomePageBase，按需重写 on_enter / on_exit / on_enter_animation。
```

`Home` 对外入口：

- `switch_to(tab_id)` — 切到指定 Tab
- `get_page(tab_id)` — 拿到页面实例
- `current_tab` / `previous_tab`

## home2.tscn 双按钮示例

`home/home2.tscn` 直接运行即可看到 2 个按钮。选中效果由场景里 `BottomBar` 节点的
`Selection Mode` 决定，当前设为 `16`（仅图标放大上移）：

| 按钮 | 选中动画 |
| --- | --- |
| 探索 | 灰底→黄底 + 宝箱图标放大上移（宽度、高度不变） |
| 背包 | 灰底→黄底 + 头盔图标放大上移（宽度、高度不变） |

两个按钮都不写 per-tab 的 `selection_mode`，因此跟随容器设置。**在检查器里改
`BottomBar` 的 `Selection Mode`，两个按钮会一起变化**；例如改成 `1`（变宽）或
`3`（变宽 + 长高）即可看到对应效果，不用改代码。

两个页面分别演示 FADE 与 SLIDE_UP 入场动画。`ICON_LIFT` 的放大倍率为 1.32、上移 22px；
动画随 `visual_selected` 同步，取消选中时图标缩小并下移回按钮居中位置。
`Home2.gd` 只负责提供 `tab_configs`，导航、动画调度、快速点击处理全部复用 `Home.gd` 和 `BottomBar`。

## 验证

```bash
# 自动化断言（按钮数量、宽度、变高、换图、铺满）
godot --headless --path <proj> -s res://tests/verify_bottom_bar.gd

# 渲染截图（输出到 tests/shots/）
godot --path <proj> -s res://tests/shoot_bottom_bar.gd
```

已实测覆盖 2 按钮与 5 按钮 × 各模式组合，以及 `home2.tscn` 的 per-tab 效果覆盖，全部通过。
截图输出到 `tests/shots/`，其中包含 `2btn_icon_lift.png`、`home2_explore.png` 与 `home2_bag.png`。
