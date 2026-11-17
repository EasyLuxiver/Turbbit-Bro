# 网页版试玩部署

## 国内链接（CloudBase）

- 地址：**https://turbbit-bro-d9g2a2xh1229108f2-1463989963.tcloudbaseapp.com/**
- 环境：`turbbit-bro-d9g2a2xh1229108f2`（腾讯云开发国内站，体验版，静态托管 Online）
- 当前部署：FEEL-48 构建（2026-11-17，index.pck 2.81 MB / index.wasm 39.5 MB；CloudBase 同源加载）
- 首次打开会看到 CloudBase 测试域名风险提示：等 3 秒点 **“确定访问”**，之后进入游戏；同一浏览器之后不再提示。
- 默认域名是测试域名，有访问频率限制；长期稳定需要绑定已备案的自定义域名。
- 实测：`index.wasm` 39.5 MB，国内 CDN 下载约 **2.3 秒**（22 MB/s），MIME `application/wasm`；首屏含 4 秒提示页约 28 秒。
- 部署：`tcb hosting deploy <build/web> -e turbbit-bro-d9g2a2xh1229108f2 --verify`

## GitHub Pages（备用）

- 构建：Godot 4.7 Web（Compatibility / 单线程，无需 COOP/COEP）
- 产物：`TURBBIT/build/web/index.html` + `index.pck` + `index.wasm`
- 托管：GitHub Pages，分支 `gh-pages`（只放构建产物，不动源码分支）
- 地址：**https://easyluxiver.github.io/Turbbit-Bro/**
- 大文件：`index.wasm` / `index.pck` 走 jsDelivr（`testingcf.jsdelivr.net`，国内比 github.io 快）；
  25 秒无进度或加载失败会自动切回同源（GitHub Pages）重试
- 实测：公网首屏 30 秒（wasm 9.1 MB / pck 2.1 MB，桌面 Edge headless）

## 本地复现

```
D:\Godot_v4.7-stable_win64_console.exe --headless --path D:\GAMESTUDIO\TURBBIT ^
  --export-release "Web" "D:\GAMESTUDIO\TURBBIT\build\web\index.html"
python -m http.server 8060 --directory D:\GAMESTUDIO\TURBBIT\build\web
```

浏览器打开 `http://127.0.0.1:8060/index.html`，点画面按 Enter。

## 重新导出后

导出会重写 `index.html`，需要重新打 CDN + 回退补丁：

```
python D:\GAMESTUDIO\.tools\webtest\patch_web.py D:\GAMESTUDIO\TURBBIT\build\web\index.html
```

然后把 `build/web` 的产物复制到 `gh-pages` 分支（不放 `_shots`、`*.import`、`*.gz`）。

## 关键设置

- `project.godot`：`renderer/rendering_method.web="gl_compatibility"`
- 导出预设 `Web`：`variant/thread_support=false`，`exclude_filter` 与 Windows 包一致
- 中文：打包 `assets/fonts/NotoSansSC-Turbbit.otf`（Noto Sans CJK SC 子集，约 253 KB，OFL）
  - Web 无系统字体回退，默认字体不含中日韩字形，必须打包
  - `Locale._ready()` 在 Web 上把它设为默认字体；`CanvasLayer` 会截断主题继承，因此给挂在 `CanvasLayer` 下的根 Control 直接装主题
- `index.wasm` 39.5 MB；gzip 后 10.1 MB，供需要 25 MB 单文件上限的托管使用

## 平台范围

- Windows / macOS / Linux 的 Chrome、Edge、Safari（WebGL2）
- 键盘操作；不支持触屏 / 手机
- 首次加载需要下载 wasm，之后有浏览器缓存

## 已知限制

- CloudBase 默认域名会先显示测试域名风险提示，需点一次“确定访问”；有频率限制，长期给队友玩需要备案自定义域名
- GitHub Pages 在国内的速度取决于线路；国内优先用上面的 CloudBase 链接
- Web 版没有做移动端适配
