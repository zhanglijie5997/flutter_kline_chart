# kline_chart

[English](README.md) | 简体中文

一个轻量、高性能的 Flutter 金融 **K 线(蜡烛图)** 组件 —— 忠实移植自 [klinecharts / KLineChart](https://github.com/klinecharts/KLineChart)(v10.0.0-beta3)的 Dart 版本。

原库基于 HTML5 canvas 渲染、由 DOM 驱动。本移植在保持绘制/指标逻辑与原库一致的同时,把外壳重构成 Flutter 原生:

- HTML5 `Canvas` / `CanvasRenderingContext2D` → 用 **`Ctx` 适配器**在 `dart:ui.Canvas` 上绘制,该适配器镜像了 Canvas 2D API。
- DOM 容器 + 鼠标/触摸事件 → 一个 **`KLineChartWidget`**,配合 `GestureDetector` / `Listener`。
- `Store` 状态 + 坐标引擎 → 一个 **`ChartStore`(`ChangeNotifier`)**,逐方法移植。

---

## 目录

- [特性](#特性)
- [安装](#安装)
- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [数据](#数据)
- [指标](#指标)
- [交互:点击、十字光标、缩放、滚动](#交互)
- [买卖点标记](#买卖点标记)
- [样式](#样式)
- [实用配方](#实用配方)
  - [币安实时数据(REST + WebSocket)](#币安实时数据)
  - [横屏全屏看盘](#横屏全屏看盘)
  - [跟随十字光标的浮窗面板](#跟随浮窗面板)
  - [滚动到左侧时加载更早历史(分页)](#滚动分页加载)
  - [只显示成交量的副面板](#只显示成交量的副面板)
- [API 速查](#api-速查)
- [架构](#架构)
- [尚未移植](#尚未移植)
- [许可证](#许可证)

---

## 特性

- 图表类型:**蜡烛图**、**柱状/空心**、**OHLC**、**面积图**
- 平滑的**滚动**与**缩放** —— 鼠标滚轮、触控板/手指双指缩放、拖动 —— 以及程序化的 `zoomIn/zoomOut/scrollBy`
- **十字光标**,带数值 + 时间标签(桌面 hover、移动端长按拖动 / 点击),并有连续回调 `onCrosshairChange`
- 自动缩放的 **Y 轴**(nice 刻度)和随周期变化的 **X 轴**(标签按时间周期格式化)
- 最高/最低价标记、最新价线 + 标签
- **27 个内置技术指标**,可叠加在主图或放到各自的副面板;支持增/删/改/注册自定义
- **顶部图例**(按指标、颜色对应),可按指标显示/隐藏
- **买卖点标记** —— 内置 canvas 标记,或通过 `markerBuilder` 用完全自定义、可交互的 Flutter widget
- 明/暗主题;所有样式都是可覆盖的嵌套 `Map`
- 可注册自定义**指标**和**图形(figure)**

### 内置指标

`MA` `EMA` `SMA` `BBI` `VOL` `MACD` `BOLL` `KDJ` `RSI` `BIAS` `BRAR` `CCI` `DMI`
`CR` `PSY` `DMA` `TRIX` `OBV` `VR` `WR` `MTM` `EMV` `SAR` `AO` `ROC` `PVT` `AVP`

---

## 安装

在你 App 的 `pubspec.yaml` 里添加依赖(path 或 git):

```yaml
dependencies:
  kline_chart:
    path: ../kline_chart          # 本地路径
    # git: https://github.com/klinecharts/KLineChart
```

```dart
import 'package:kline_chart/kline_chart.dart';
```

> **网络提示:** 如果需要联网拉数据(见币安配方),要配好平台权限 —— Android 的 `INTERNET` 权限(debug 默认有),macOS 需要 `com.apple.security.network.client` entitlement。

---

## 快速开始

一切由 `KLineChartController` 驱动,`KLineChartWidget` 负责渲染。

```dart
import 'package:flutter/material.dart';
import 'package:kline_chart/kline_chart.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});
  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final KLineChartController controller;

  @override
  void initState() {
    super.initState();
    controller = KLineChartController(styles: darkStyleOverrides())
      ..setSymbol(SymbolInfo(ticker: 'BTCUSDT', pricePrecision: 2, volumePrecision: 3))
      ..setPeriod(const Period(type: 'day', span: 1))
      ..applyNewData(myBars); // List<KLineData>

    // MA 叠加在主图;VOL + MACD 放各自的副面板。
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    controller.createIndicator('VOL');
    controller.createIndicator('MACD');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1F),
      body: SafeArea(
        child: KLineChartWidget(
          controller: controller,
          backgroundColor: const Color(0xFF1B1B1F),
        ),
      ),
    );
  }
}
```

一个完整可运行的示例 —— 币安 BTC/USDT 实时数据、时间周期切换、指标、标记、缩放按钮、横屏全屏 —— 在 [`example/`](example/lib/main.dart)。

---

## 核心概念

| 概念 | 说明 |
|---|---|
| `KLineChartController` | 公开 API + 状态持有者。创建一个、喂数据、加指标、读取/驱动视口。用完 `dispose()`。 |
| `KLineChartWidget` | 渲染面板。接收 controller + 可选回调(`onCandleTap`、`onCrosshairChange`、`markerBuilder`)。随 controller 变化自动重绘。 |
| `KLineData` | 一根 K 线:`timestamp`(毫秒,`int`)、`open/high/low/close`(`double`)、可选 `volume`/`turnover`。 |
| **面板(Pane)** | 主图(id 为 `KLineChartController.candlePaneId`)加每个指标副面板;X 轴在底部。 |
| **样式(Styles)** | 深层嵌套的 `Map<String, dynamic>`(与原库一致),深合并到默认样式之上。无需代码生成 —— 就是 Map。 |
| **数值约定** | 坐标/价格是 `double`;下标、时间戳、计数是 `int`。 |

controller 是对 `ChartStore`(一个 `ChangeNotifier`)的薄封装;widget 监听它并重绘。状态(数据、指标、标记、缩放/滚动位置)都在 controller 上,所以 widget 重建、屏幕旋转都不会丢。

---

## 数据

```dart
// 全量重置(初次加载,或切换品种/周期):
controller.applyNewData(bars); // List<KLineData>

// 追加最新一根 或 更新正在形成的那根(比如 websocket tick):
controller.updateData(KLineData(
  timestamp: ts, open: o, high: h, low: l, close: c, volume: v,
));

// 前插更早的历史(分页 / 向左无限滚动):
controller.prependData(olderBars);

// 读回:
final bars = controller.getDataList();
```

从 JSON 构造用 `KLineData.fromMap(map)`(读取 `timestamp/open/high/low/close/volume/turnover`,其余键保留)。

`updateData` 自动判断:`timestamp` 更新 → 追加一根;`timestamp` 相等 → 替换最后一根(“正在形成的 K 线”场景)。

---

## 指标

```dart
// 加到一个新副面板;返回创建的 pane id:
final paneId = controller.createIndicator('RSI');

// 叠加在主图,而不是副面板:
controller.createIndicator('BOLL', paneId: KLineChartController.candlePaneId);

// 在同一面板叠多个指标:
controller.createIndicator('EMA', paneId: paneId, isStack: true);

// 自定义计算参数:
controller.createIndicator('MA', calcParams: [7, 25, 99]);

// 单个指标的样式 —— 例如隐藏“这个”指标的图例文字
// (其他指标的图例保留):
controller.createIndicator('VOL', styles: {'tooltip': {'showRule': 'none'}});

// 只显示成交量柱(去掉均量线):传空 calcParams
controller.createIndicator('VOL', calcParams: <dynamic>[]);

// 更新已有指标:
controller.overrideIndicator(IndicatorCreate(name: 'MA', calcParams: [10, 20]));

// 移除(按 面板 / 名称 / id):
controller.removeIndicator(name: 'RSI');

// 列出全部可用指标:
controller.supportedIndicators(); // ['MA', 'EMA', 'VOL', 'MACD', ...]
```

**注册自定义指标**(通过 `registerIndicator` 全局可用):

```dart
registerIndicator(IndicatorTemplate(
  name: 'MY',
  shortName: 'MY',
  precision: 2,
  figures: const [
    IndicatorFigure(key: 'v', title: 'MY: ', type: 'line'),
  ],
  // 每根 K 线返回一个 Map,键为 figure 的 `key`。
  calc: (dataList, indicator) => [
    for (final d in dataList) <String, dynamic>{'v': d.close},
  ],
));
controller.createIndicator('MY');
```

figure 的 `type` 为 `'line'`、`'bar'`、`'circle'`、`'text'` 之一。figure 的 `styles` 回调可以给每个点上色(例如 `VOL` 的涨跌着色)。

---

## 交互

### 点击 & 十字光标回调

```dart
KLineChartWidget(
  controller: controller,
  // 单次点击某根 K 线:
  onCandleTap: (KLineData data, Offset localPos) {
    // 比如弹出详情浮窗
  },
  // 连续 —— 聚焦的 K 线变化时触发(hover / 长按拖动 / 点击);
  // 光标移出图表时 data 为 null:
  onCrosshairChange: (KLineData? data, Offset? localPos) {
    setState(() => _focused = data);
  },
)
```

也可以订阅 action / 直接读取当前聚焦的 K 线:

```dart
controller.subscribeAction(ActionTypes.onCandleBarClick, ([data]) {
  final bar = data as KLineData;
});
final focused = controller.crosshairData; // KLineData?
```

可用的 action 类型:`ActionTypes.onZoom`、`onScroll`、`onVisibleRangeChange`、
`onCrosshairChange`、`onCandleBarClick` 等。

### 程序化缩放 / 滚动

内置手势(拖动滚动、滚轮/双指缩放)一直可用。此外:

```dart
controller.zoomIn();               // 放大,以图表中心为锚点
controller.zoomOut();
controller.zoomBy(step);           // step > 0 放大(每单位约 10%)

controller.startScroll();
controller.scrollByDistance(120);  // 按像素水平滚动

controller.setZoomEnabled(false);  // 需要的话禁用手势
controller.setScrollEnabled(false);
```

---

## 买卖点标记

把交易信号标记锚定到某根 K 线的 `(timestamp, price)`;它们绘制在主图上,随滚动/缩放一起移动。

```dart
controller.setMarkers([
  TradeMarker(timestamp: bar.timestamp, price: bar.low,  side: TradeSide.buy,  text: 'Buy'),
  TradeMarker(timestamp: bar.timestamp, price: bar.high, side: TradeSide.sell, text: 'Sell'),
]);
controller.addMarker(marker);   // 追加一个
controller.clearMarkers();
```

默认标记画成 canvas 三角 + 标签(买入朝上、在 K 线下方;卖出朝下、在 K 线上方)。

### 自定义 widget 标记

传入 `markerBuilder` 就能把标记渲染成**可交互的 Flutter widget** —— builder 拿到每个标记(那根 K 线的买卖信息),返回任意 widget,定位在主图上并随滚动/缩放保持同步:

```dart
KLineChartWidget(
  controller: controller,
  markerBuilder: (context, m) {
    final buy = m.side == TradeSide.buy;
    return GestureDetector(
      onTap: () => showDetails(m),
      child: Image.network(buy ? buyIcon : sellIcon, width: 32, height: 32),
      // ...或任意 Chip / Container / 气泡
    );
  },
)
```

设置了 `markerBuilder` 后,canvas 三角会被跳过。买入 widget 以点为顶部居中锚点(挂在下方);卖出 widget 以点为底部居中锚点(悬在上方)。

想给自己的覆盖层拿像素坐标?`controller.pointToPixel(timestamp, price)`(或 `markerToPixel(marker)`)返回图表内的 `Offset`。

---

## 样式

样式是嵌套的 `Map<String, dynamic>`,深合并到默认之上。可在构造时(`KLineChartController(styles: ...)`)设置,也可随时用 `setStyles`:

```dart
controller.setStyles(<String, dynamic>{
  'candle': {
    'type': CandleTypes.area, // candle_solid | candle_stroke | ohlc | area | ...
    'bar': {'upColor': '#26A69A', 'downColor': '#EF5350'},
  },
  'grid': {'show': false},
});

// 主题(覆盖 Map):
controller.setStyles(darkStyleOverrides());
controller.setStyles(lightStyleOverrides());
```

常用样式配方:

```dart
// 隐藏顶部 OHLCV 图例(保留指标图例):
controller.setStyles({'candle': {'tooltip': {'showRule': 'none'}}});

// 隐藏单个指标的图例:
controller.createIndicator('VOL', styles: {'tooltip': {'showRule': 'none'}});
```

`showRule` 为 `'always'` | `'follow_cross'` | `'none'`。完整默认样式树是 `getDefaultStyles()`;可以直接翻它来查所有键(`candle`、`indicator`、`xAxis`、`yAxis`、`grid`、`crosshair`、`separator`、`overlay`)。

---

## 实用配方

### 币安实时数据

示例内置了一个小巧的 [`BinanceSource`](example/lib/binance.dart),用公开、免 key、不地域封锁的 `*.binance.vision` 端点:

```dart
// REST 历史:
final bars = await binance.fetchHistory(period, limit: 1000);
controller..setPeriod(period)..applyNewData(bars);

// WebSocket 实时 kline(正在形成的 + 已收盘的):
binance.subscribe(period, controller.updateData);
```

`fetchHistory` 把 `Period` 映射到币安 interval(`1m`、`1h`、`1d`、`1w`、`1M`……;年线用月线聚合)。完整类 + 时间周期切换条(`1m … 1Y`)见示例。

### 横屏全屏看盘

```dart
@override
Widget build(BuildContext context) {
  final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
  if (landscape) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return Scaffold(body: KLineChartWidget(controller: controller));
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  return Scaffold(appBar: AppBar(...), body: Column(children: [
    _timeframeBar(),
    // 例如竖屏时取屏幕高的一半:
    SizedBox(height: MediaQuery.of(context).size.height / 2, child: chart),
  ]));
}
```

controller 不随旋转重建,所以切换是无缝的。

### 跟随浮窗面板

用 `onCrosshairChange` 驱动一个角落面板,并翻到对侧角,避免挡住聚焦的 K 线:

```dart
final onLeftHalf = (_focusLocal?.dx ?? 0) < width / 2;
Positioned(
  top: 8,
  left:  onLeftHalf ? null : 8,
  right: onLeftHalf ? 8 : null,
  child: IgnorePointer(child: _infoCard(_focused!)),
);
```

### 滚动分页加载

滚动到接近左边缘时前插更早的 K 线。`controller.oldestBarX` 是最老一根的内容 x 坐标;当它进入距左边缘 50px 内时触发:

```dart
controller.store.addListener(() {
  if (_loadingMore || _noMore) return;
  final x0 = controller.oldestBarX;
  if (x0 != null && x0 >= -50) _loadOlder(); // 距左边缘 50px 内
});

Future<void> _loadOlder() async {
  _loadingMore = true;
  final oldest = controller.getDataList().first.timestamp;
  final older = await api.fetchBefore(oldest);   // 拉 `oldest` 之前的 K 线
  if (older.isEmpty) { _noMore = true; }
  else { controller.prependData(older); }         // 右侧锚定,视图不跳动
  _loadingMore = false;
}
```

`prependData` 保持右侧锚定,所以当前可见的 K 线不动,更早的历史出现在左侧。(币安 `klines` 接口用 `endTime` 参数实现 —— 见 `example/lib/binance.dart`。)

### 只显示成交量的副面板

`VOL` 默认显示成交量柱 + 均量线。传空 `calcParams` 去掉均量线,只留柱:

```dart
controller.createIndicator('VOL', calcParams: <dynamic>[], styles: {'tooltip': {'showRule': 'none'}});
```

---

## API 速查

### `KLineChartController`

```dart
KLineChartController({Map<String, dynamic>? styles, String? locale, String? timezone});
```

| 分组 | 成员 |
|---|---|
| 数据 | `applyNewData(List<KLineData>, {bool more})` · `updateData(KLineData)` · `prependData(List<KLineData>)` · `getDataList()` |
| 品种 / 周期 | `setSymbol(SymbolInfo)` · `getSymbol()` · `setPeriod(Period)` · `getPeriod()` · `setTimezone(String)` · `getTimezone()` |
| 样式 | `setStyles(dynamic)` · `getStyles()` |
| 指标 | `createIndicator(name, {isStack, paneId, calcParams, styles}) → String?` · `overrideIndicator(IndicatorCreate)` · `removeIndicator({paneId, name, id})` · `supportedIndicators()` · 静态 `candlePaneId` |
| 标记 | `markers` · `setMarkers(List<TradeMarker>)` · `addMarker(TradeMarker)` · `clearMarkers()` · `markerToPixel(m)` · `pointToPixel(ts, price)` |
| 缩放 / 滚动 | `zoomIn([step])` · `zoomOut([step])` · `zoomBy(step)` · `zoomAtCoordinate(scale, x)` · `startScroll()` · `scrollByDistance(px)` · `setZoomEnabled(bool)` · `setScrollEnabled(bool)` |
| Action | `subscribeAction(type, cb)` · `unsubscribeAction(type, [cb])` · `crosshairData` |
| 生命周期 | `dispose()` |

### `KLineChartWidget`

| 参数 | 类型 | 说明 |
|---|---|---|
| `controller` | `KLineChartController` | 必填 |
| `backgroundColor` | `Color` | 默认白色 |
| `onCandleTap` | `void Function(KLineData, Offset)?` | 点击某根 K 线 |
| `onCrosshairChange` | `void Function(KLineData?, Offset?)?` | 连续聚焦更新 |
| `markerBuilder` | `Widget Function(BuildContext, TradeMarker)?` | 自定义 widget 标记 |

### 主要导出类型

`KLineData` · `SymbolInfo` · `Period`(`type`:`'second'…'year'`,`span`)· `Crosshair` ·
`Coordinate` · `Bounding` · `TradeMarker` / `TradeSide` · `IndicatorTemplate` / `IndicatorFigure` /
`IndicatorCreate` · `ActionTypes` · `CandleTypes` / `LineTypes` / `PolygonTypes`(枚举字符串常量)·
`getDefaultStyles()` / `lightStyleOverrides()` / `darkStyleOverrides()` / `registerStyles` ·
`registerIndicator` / `getSupportedIndicators` · `registerFigure` / `getSupportedFigures` ·
工具函数:`parseColor`、`calcTextWidth`、`formatBigNumber`、`clone`、`merge`、`isValid`……

---

## 架构

| 原库(TypeScript) | 本移植(Dart) |
|---|---|
| HTML5 Canvas / `CanvasRenderingContext2D` | `CustomPainter` + `dart:ui.Canvas`,经 `Ctx` 适配器(`lib/src/common/ctx.dart`) |
| DOM 容器 + 分层 canvas | `KLineChartWidget`(`StatefulWidget`)+ `CustomPaint` |
| DOM 鼠标 / 触摸事件 | `GestureDetector` / `Listener` |
| `Store` 状态 + 坐标引擎 | `ChartStore`(`ChangeNotifier`)—— 忠实移植 |
| `Indicator` / `Figure` / `View` | 1:1 移植(指标、图形、绘制视图) |
| CSS 颜色字符串 | `parseColor()` → `dart:ui.Color` |

包结构与原库对应:`lib/src/{common, component, view, pane, extension/{figure,indicator}}`,外加 `store.dart`、`kline_chart_controller.dart`、`kline_chart_painter.dart`、`kline_chart_widget.dart`。

---

## 尚未移植

已移植并可用:数据引擎、坐标/滚动/缩放系统、蜡烛与指标渲染、坐标轴、十字光标、顶部图例、tooltip、全部 27 个内置指标,以及买卖点标记(canvas + 自定义 widget)。

尚未从原库移植:完整的交互式**绘图 overlay**(趋势线 / 形状)、流式 `DataLoader` 分页钩子、i18n 语言包、tooltip 功能按钮、快捷键。架构与原库一致,这些可以按同样的模式补上。

---

## 许可证

Apache-2.0,与上游 [klinecharts](https://github.com/klinecharts/KLineChart) 项目一致。
