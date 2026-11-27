# 更新日志 · Changelog

每个版本先中文、后英文。发版时把对应版本的正文（不含版本标题）作为 Release 正文，见 `docs/release.md`。


## 1.4.0-sub.2 · 2026-11-27

### 中文

- **修复:输入文字动画在长文本里不再丢字。** 叠加层测量文字时不再受输入框最大行数截断,超出可见范围的内容在滚动后照常显示;光标也不会再跳回左上角。
- **修复:按回车换行后光标跟着到新行。** 换行符自己的排版框落在上一行末尾,现在光标改用新行第一个字符的位置;末尾空行从行首起算,RTL 也落在正确的一侧。
- **修复:同一帧内文本和选区都变化时不再重复启动动画时钟。** 粘贴或移动光标不会再触发 “A ticker was started twice”。
- **验证情况。** 全量 CI 绿灯,代码审查没有遗留问题;真机上的长文本、换行与越南语输入法观感仍需装上新版本确认。

### English

- **Fixed: the typing animation no longer drops letters in long drafts.** The overlay measures the whole draft instead of stopping at the composer's maximum lines, so text past the visible rows shows up when the field scrolls and the caret no longer jumps to the top-left.
- **Fixed: the caret follows a new line after Enter.** The line break's own box sits at the end of the old line; the caret now anchors to the first glyph of the new one, or to the line start for a trailing break, with the correct side in RTL.
- **Fixed: text and selection changes in the same frame no longer restart the animation ticker.** Pasting or moving the caret can no longer trigger "A ticker was started twice".
- **Testing.** Full CI is green and the code review found no remaining issues; the long-draft, newline and Vietnamese IME behavior still needs a check on a real device.


## 1.4.0-sub.1 · 2026-11-27

### 中文

- **修复:输入文字动画按参考插件重做。** 文字差异改用公共前后缀,只对真正新来的字做动画;删除不再只是淡出,而是按插件的粒子效果掉落或化屑;淡入缓动、模糊、弹出、倾斜与错开时间都对齐 `TypingFx`,光标改成圆角滑块并按弹簧速度跟随。
- **修复:关闭底部弹层时背景后退不再瞬间跳回。** 弹层退出时路由已不算“当前”,改动后仍继续跟随它的反向动画,页面会随弹层一起恢复原尺寸。
- **同步:合入上游的新改动。** 包括回复脚注里的解码速度、远程后台连接与状态、tawcroot 兼容等。更新检查仍按本 fork 的设定走自己的 GitHub Releases,没有改用上游的下载源。
- **验证情况。** 全量 CI 绿灯;真机上的动画观感与流畅度仍需装上新版本确认。

### English

- **Fixed: the typing animation was rebuilt to match the reference plugin.** Edits are diffed by common prefix/suffix, so only newly arrived letters animate. Deleting now spawns falling glyphs or dust particles instead of a plain fade; easing, blur, pop, tilt and stagger follow `TypingFx`, and the caret is a rounded spring-driven slider.
- **Fixed: the sheet recede no longer snaps back when a bottom sheet closes.** A popping route stops being "current" immediately, but the page now keeps following its reverse animation and returns to full size with the sheet.
- **Synced: newer upstream changes are merged.** These include decoding speed in reply footnotes, remote background connectivity and status, and tawcroot compatibility. Update checks still use this fork's own GitHub Releases, not the upstream download sources.
- **Testing.** Full CI is green; the animation feel and smoothness still need a check on a real device.


## 1.3.0-sub.8 · 2026-11-25

### 中文

- **完善:输入文字动画的选项补齐到参考插件。** 「输入文字动画设置」新增「试一试」预览输入框,并把选项分成打字、调整、删除、光标四组:单字淡入/上浮、模糊、弹出与倾斜可以单独开关;速度 120–900 毫秒、上移 2–30 dp、弹出/倾斜强度 25–200%、光标速度 6–40 都可细调;删除效果新增「什么都不做」。选项按开关条件显示,父效果关闭时子选项不再占着位置。
- **修复:从底部弹层打开新页面后,原来的页面不再卡在缩小状态。** 背景后退现在按当前路由重新计算:新页面盖上来时原页面恢复原尺寸,返回弹层后重新后退,关掉弹层才彻底复原。
- **范围说明:「每个输入框都生效」目前只覆盖预览框和聊天输入框。** 开关会保存,但把效果铺到全 App 所有文本输入框是另一项改造,这个版本还没有做。
- **验证情况。** 全量 CI 绿灯,代码审查没有问题;真机上的动画观感与流畅度仍需装上新版本确认。

### English

- **Completed: the typing-animation options now match the reference plugin.** The "Typing animation options" sheet gains a live "Try it" field and four groups — Typing, Adjust, Deleting and Cursor. Letters, slide-up, unblur, pop and tilt can be toggled independently; speed (120–900 ms), slide distance (2–30 dp), pop/tilt strength (25–200%) and cursor speed (6–40) are fine-tunable, and "Nothing" is available as the delete effect. Sub-options hide when their parent effect is off.
- **Fixed: pushing a screen from a bottom sheet no longer leaves the old page shrunk.** Recede now recomputes from the current route: the page returns to full size under the pushed screen, sits back again when the sheet is current, and settles only when the sheet closes.
- **Scope note.** "Every text field" is persisted but currently applies to the preview field and the chat composer only; applying it to all text fields across the app remains a separate change.
- **Testing.** Full CI is green and the code review found no issues; the animation feel and smoothness still need a check on a real device.


## 1.3.0-sub.7 · 2026-11-25

### 中文

- **改进:底部弹层的「背景后退」更顺了。** 背景缩小到 0.9(和 Mochy 一样),不再和弹层共用一条曲线:分三段关键帧走——弹层刚升起时先退一步、中间放慢、快到位时轻轻落住;最后 0.05% 直接归位,避免收尾一跳。
- **新增:聊天输入框的输入文字动画(设置 → 性能 → 界面效果)。** 开启后新字逐个淡入上浮,删除的字掉落或化屑,光标会弹性滑到新位置并留下淡淡的拖尾;同页的「输入文字动画设置」可调单字速度、上移距离、删除效果与光标样式。只在灵动动效档生效,默认关闭,IME 拼写过程不做逐字动画。
- **验证情况。** 全量 CI 绿灯;真机上的动画观感与流畅度仍需装上新版本确认。

### English

- **Improved: the sheet's recede animation is smoother.** The page behind scales to 0.9, like Mochy, and no longer shares the sheet's single curve: three keyframes step it back as the sheet rises, coast through the middle and land softly, with a tiny end threshold so it doesn't snap at the finish.
- **New: typing animation for the chat composer (Settings → Performance → Interface effects).** When enabled, new letters fade in and rise one by one, deleted letters fall away or turn to dust, and the caret glides to its new position with a faint trail. The "Typing animation options" sheet on the same page controls letter speed, slide distance, delete style and cursor style. It rides on the fluid tier, is off by default, and skips IME composition.
- **Testing.** Full CI is green; the animation feel and smoothness still need a check on a real device.


## 1.3.0-sub.6 · 2026-11-25

### 中文

- **改进:插件页的「添加插件」不再用系统下拉菜单。** 注册源选择改成 App 自己的底部弹层:选项带图标和地址说明,当前项打勾,弹层不会再盖住「取消 / 安装」按钮。这个选择器也抽成了通用组件,其他下拉以后可以逐步换过来。
- **新增:Android 也有底部弹层的「背景后退」效果。** 弹层升起时后面的页面会轻微缩小、四角变圆并让出状态栏位置,跟手移动;和 iOS 一样只在灵动动效 + 手机尺寸下启用,低端机或发热降档时自动关闭。
- **验证情况。** 全量 CI 绿灯;真机上的弹层观感和状态栏图标颜色仍需装上新版本确认。

### English

- **Improved: the Add plugin dialog no longer uses a system dropdown.** The registry picker is now an app bottom sheet: options carry an icon and their address, the current one is ticked, and the menu no longer covers Cancel / Install. The control is shared, so other dropdowns can migrate later.
- **New: the sheet "recede" effect comes to Android.** While a sheet rises, the page behind scales down slightly, rounds its corners and leaves room for the status bar, following the sheet and the finger. As on iOS it stays on the fluid tier and phones only, and switches off on low-end or thermally limited devices.
- **Testing.** Full CI is green; the sheet feel and status-bar icon colour still need a check on a real device.


## 1.3.0-sub.5 · 2026-11-25

### 中文

- **新增:插件图标也认 SVG 了。** 上版开始,已安装列表会回退到插件目录里的图标;这次连 `data:image/svg+xml` 图片和 `.svg` 链接也能直接渲染,像 `dsh-context` 这种只在包里放 SVG 的插件不用再显示首字母。图标内容不合法时照旧回退,不会让列表崩掉。
- **验证情况。** 全量 CI 与 OHOS 编译均绿;真机显示仍需装上新版本确认。

### English

- **New: plugin icons can be SVG.** The previous release made the Installed list fall back to the plugin directory's icon; inline `data:image/svg+xml` images and `.svg` links now render too, so packages that only ship an SVG such as `dsh-context` no longer show an initial letter. Malformed icons still fall back instead of breaking the list.
- **Testing.** Full CI and the OHOS compile are green; the on-device display still needs a check after installing the new build.


## 1.3.0-sub.4 · 2026-11-25

### 中文

- **修复:分支状态会自己刷新。** 在别的终端提交或切分支后,输入框旁的分支 chip 和分支面板每 30 秒、回到 App、打开面板时都会重新读取,不必关掉对话再进来;本地未暂存的改动也会让小圆点跟着变。
- **修复:重连后分支不再卡旧值。** SSH 重新登录、中继重连、本机引擎换了地址或令牌这类“换了客户端”的重连会重新探测 git;单纯的网络重试不会反复打扰主机。
- **修复:更深层的分支名也能列出来。** 文件探测不再在第三层目录就停下,`feature/team/topic/sub/fix` 这种名字也能正常识别。
- **修复:插件翻译跟着界面语言走。** 在英文界面翻译过的插件说明,切到中文后不再残留英文译文,也不会因为翻译按钮消失而无法还原。
- **修复:已安装插件在原生界面也有图标。** 以前原生只认插件自带的图片,大多数插件没有,所以只显示首字母;现在会回退到插件目录里的图标,和网页端一致,插件自带的图标仍优先。
- **新增:原生界面也能自由添加插件。** 「插件」页右上角多了 `+`,和网页端一样可以填 npm 包名、GitHub 仓库地址或主机上的本地目录,并选择国内镜像、官方 npm 源或自定义 https 源;安装进度、失败原因和重启提示沿用原有流程。不能安装的主机不会显示这个按钮。
- **验证情况。** 全量 CI 与 OHOS 编译均绿;真机上的分支切换、克隆、图标显示和新安装流程仍需装上新版本后确认。

### English

- **Fixed: git branch state refreshes itself.** After a commit or a branch switch in another terminal, the composer chip and the branch sheet re-read every 30 seconds, when the app resumes and when the sheet opens — no need to leave the chat. Unstaged edits now update the dirty dot as well.
- **Fixed: a reconnect no longer freezes the branch on an old value.** Reconnects that replace the client — SSH re-login, relay reconnect, a local engine with a new address or token — re-probe git, while a plain retry does not spam the host.
- **Fixed: deeply nested branch names are listed.** The file probe no longer stops at the third directory level, so names like `feature/team/topic/sub/fix` are recognised.
- **Fixed: plugin translations follow the UI language.** A description translated while the UI was English no longer stays in English after switching to Chinese, and the translate button no longer disappears with no way to undo it.
- **Fixed: installed plugins have icons in the native UI too.** Native used to read only an image shipped inside the bundle, which most plugins do not have, so it showed an initial letter. It now falls back to the plugin directory's icon, matching the web UI; a bundle's own icon still wins.
- **New: free-form plugin installation in the native UI.** A `+` action on the Plugins screen accepts an npm package name, a GitHub repository URL or a directory on the Host, with a choice of the China mirror, the official npm registry or a custom https registry. Progress, failure reasons and restart prompts reuse the existing install flow; the button is hidden on Hosts that cannot install.
- **Testing.** Full CI and the OHOS compile are green. Branch switching, cloning, icon display and the new install flow still need a real-device check after installing the new build.


## 1.3.0-sub.3 · 2026-11-25

### 中文

- **修复:插件列表按 App 语言显示。** 界面是英文时,插件名称和说明原来仍默认显示中文。现在「已安装」列表和插件详情会优先取插件提供的当前语言文本,没有对应翻译时照旧回退,不会因此变空。

### English

- **Fixed: the plugin list follows the app's language.** Plugin names and descriptions used to default to Chinese even with an English UI. The Installed list and the plugin sheet now prefer the plugin's text in the current language, falling back as before when a translation is missing, so nothing goes blank.


## 1.3.0-sub.2 · 2026-11-24

### 中文

- **分支入口收进输入框。** 原来 `+` 面板里的分支行改成输入框旁的小 chip:只显示图标和分支名,点开还是同一张分支面板。名字太长会省略,不会挤掉模型选择。
- **认得 linked worktree 了。** 以前 `.git` 是文件的仓库(agent team / worktree 常见)整块被当成非 git 目录。现在会话里有终端时直接问 git,能认出分支、远程分支和 worktree;没有终端的新对话仍读文件,不会因此报错。
- **未提交的改动有提示。** chip 上的小圆点和分支面板里的计数都来自 `git status`,在切换前就能看见。切到别的分支时仍由 git 自己拒绝并原样显示原因,不会替你动工作区。
- **分支面板多两项。** 远程分支单独一页,点 `origin/develop` 会切出本地 `develop`;「新建分支」输名字后走 `git checkout -b`。分支名照旧先校验再进命令行。
- **克隆不限于本机。** 远端主机只要有终端也能用「克隆仓库」,文件夹必须自己选,因为 App 不猜远端主机的默认目录。
- **验证情况。** 终端探测命令在本机 shell 里量过:根目录和子目录都正确识别为普通仓库,非仓库目录不输出,带大量 refs 的仓库输出被限制在 2 万字节以内。CI 结果见对应提交;真机克隆/切换分支仍待设备验证。

### English

- **The branch entry moved into the composer.** The row in the `+` panel is now a small chip beside the model pill: icon and branch name only, opening the same sheet. Long names ellipsize instead of pushing the model selector away.
- **Linked worktrees are recognised.** A repository whose `.git` is a file — common with agent teams and worktrees — was treated as "not git". A conversation with a terminal now asks git directly for the branch, remote branches and worktree state; new chats without a session still read files and never error because of it.
- **Uncommitted changes are visible.** A dot on the chip and a count in the sheet come from `git status`, so they show before a switch is attempted. git itself still refuses a switch that would overwrite local changes, and its message is shown unchanged.
- **Two more entries in the sheet.** Remote branches live on their own page; tapping `origin/develop` checks out a local `develop`. "New branch" asks for a name and runs `git checkout -b`. Names are validated before reaching a shell as before.
- **Cloning is no longer local-only.** A Remote Host with a terminal can clone too; the destination folder must be picked explicitly because the app cannot guess that Host's default directory.
- **Testing.** The probe command was measured in a local shell: a normal repository is recognised from both its root and a subdirectory, a non-repository prints nothing, and a repo with many refs stays under 20 KB of output. See the corresponding commit for CI; cloning and branch switching still need a real-device run.


## 1.3.0-sub.1 · 2026-11-24

### 中文

- **应用改名为 DSH Go Enhanced。** 桌面图标、系统设置/通知里的名称、通知标题与使用说明中本 App 的自称都改为新名字;指代原版 DSH Go 应用、上游桥接与项目主页的地方保持原样。
- **版本命名改为跟随上游。** 版本名从本 fork 自增长的 `1.2.13` 改成 `<上游版本>-sub.<序号>`,首个版本是 `1.3.0-sub.1`。同一个上游版本每发一次版序号加一,由 `tooling/sub_version.py` 读取现有 tag 自动给出下一个号并同步 `pubspec.yaml` 与 `AppInfo`;构建号(versionCode、`+N`)仍是构建分钟,规则不变。
- **新增:用量弹层里直接压缩上下文。** 上下文卡片下方多了一枚「压缩上下文」按钮,点击即发送 `/compact`,结果照常显示在对话里。只有已经用上上下文时才出现;新对话还没有用量数据时不显示。
- **新增:新建对话时可克隆仓库。** 工作区列表里选「克隆仓库」,填入 GitHub/GitLab 地址、`git@host:owner/repo` 或简写 `owner/repo`(简写可选平台),再选目标文件夹。克隆完成后该文件夹立即加入工作区并设为当前工作区,失败时显示 git 自己的最后几行输出,不会留下半个工作区。
- **新增:切换 Git 分支。** 对话侧(输入框 `+` 面板的「本对话」卡片)和新建对话的选项行会显示当前分支,点开可切换本地分支。分支名与仓库地址都先校验再进命令行,脏工作区由 git 自己拒绝并原样显示原因;分支变化会自动跟随刷新(监听 `.git/HEAD`、`.git/refs/heads`、`.git/packed-refs`),所以在终端或由 Agent 改的分支也会即时反映。
- **同步上游多批合并。** 伙伴(companion)多批修复与性能优化、p2–p5 运行时/对话/外壳/原生性能轮次、论坛草稿发送、手机技能、常驻悬浮条紧凑模式、会话投影补丁(`projection-current-state.diff`)等;引擎补丁链按合并后的链重新记录。
- **验证情况。** GitHub Actions 全量 CI、OHOS 编译、iOS UI tour 均绿,补丁链 33 项测试通过。真机尚未验证:克隆/切换分支、以及新对话下的工作区探测,需要在设备上确认。

### English

- **The app is now called DSH Go Enhanced.** The launcher label, system settings and notification names, notification titles and the app's own wording in the guide use the new name; mentions of the original DSH Go app, the upstream bridge and the upstream project home are unchanged.
- **Version names now follow upstream.** The fork's own `1.2.13` sequence is replaced by `<upstream-version>-sub.<n>`; the first is `1.3.0-sub.1`. Each release against the same upstream base increments `<n>`; `tooling/sub_version.py` reads the existing tags and bumps both `pubspec.yaml` and `AppInfo`. The build number (versionCode, `+N`) is still the build minute and is unchanged.
- **New: compact the context from the usage sheet.** A “Compact context” button under the context card sends `/compact`, and its result shows in the conversation as usual. It appears only once context is in use; a new chat with no usage data does not show it.
- **New: clone a repository for a new conversation.** Choose “Clone a repository” in the workspace list, enter a GitHub/GitLab URL, `git@host:owner/repo` or the short `owner/repo` (the platform is selectable for the short form), then pick the destination folder. The cloned folder joins the workspace list immediately and becomes the active one; a failure shows git's own last lines and never leaves a half-registered workspace.
- **New: switch Git branches.** The conversation's `+` panel (“This chat” card) and the new-conversation options row show the current branch and open a picker for local branches. Branch names and repository sources are validated before they reach a shell, a dirty worktree is refused by git itself with its own message, and branch changes follow automatically (`.git/HEAD`, `.git/refs/heads`, `.git/packed-refs`), so a switch made in a terminal or by the agent shows up without reopening the sheet.
- **Synced several upstream merge batches.** Companion fixes and performance work, the p2–p5 runtime/chat/shell/native rounds, forum sent-draft handling, phone skills, an always-on float compact mode, the session projection patch (`projection-current-state.diff`) among others; the engine patch chain was re-recorded against the merged chain.
- **Testing.** Full GitHub Actions CI, OHOS compile and the iOS UI tour are green; all 33 patch-chain tests pass. Not yet verified on a real device: cloning and branch switching, and the workspace probe for a new chat, need a device run.

## 1.2.13 · 2026-11-22

### 中文

- **修复夜间代码审查发现的 10 个问题。** 更新面板在下载/安装中打开时也能发现本机其他安装器；插件翻译在关闭面板后不再因异步引用报错；README 下载按流限量，远端与 `data:` 图片改为点击才打开；导入旧版引擎数据失败后会自动重启引擎；社区源内容过旧时会继续尝试下一个源，同时保留 6 小时轮询间隔；消息里的 `@` 提及改用与输入框一致的识别规则；查询 APK 安装器移出主线程；hand-off 失败在原生侧记录具体原因、Dart 侧不再抛出未处理异常；README 的 HTML 图片地址不再能注入 Markdown；插件 island 获取失败时会清掉标志并回退，不再永久卡在加载态。
- **同步上游 79 个提交。** 包含主题包自定义与创意工坊接入、会话搜索异步读取、远程主机页面改进、动态统计与求 star 分档、Tavern/伙伴性能修正等；移植时保留了本 fork 的消息 Markdown 渲染与 `@` 提及逻辑。引擎补丁 `pins.json` 已按合并后的补丁链重新记录，Android / HarmonyOS 两条链均通过校验。
- **验证情况。** GitHub Actions 全量 CI 与 OHOS 编译均绿；补丁链 33 项测试通过。真机尚未完整验证。

### English

- **Fixed 10 issues from the nightly code audit.** The update sheet now discovers other installers even when opened mid-download/install; plugin translation no longer errors after the sheet is closed; README downloads are stream-capped and remote/`data:` images open only on tap; a failed home-data import restarts the engine; a stale community feed falls through to the next source while keeping the 6-hour poll; `@` mentions in sent messages use the same grammar as the composer; APK-installer discovery runs off the main thread; hand-off failures log a concrete reason natively and no longer raise unhandled async errors in Dart; README HTML image targets can no longer inject Markdown; a failed island acquire clears its flag and falls back instead of sticking in a loading state.
- **Synced 79 upstream commits.** Theme-pack customisation with workshop integration, async local session search, remote-host page improvements, usage stats and tiered star prompts, Tavern/companion performance fixes and more. The fork's user-message Markdown rendering and `@` mention logic were kept during the merge, and the engine patch `pins.json` was re-recorded over the merged chain — both Android and HarmonyOS chains verify clean.
- **Testing.** Full GitHub Actions CI and the OHOS compile are green; all 33 patch-chain tests pass. Not yet fully verified on a real device.

## 1.2.12 · 2026-11-21

### 中文

- **自己发的消息也能渲染 Markdown。** 在聊天里贴代码块、标题或 Markdown 链接时，消息气泡会自动识别并排版；不想看排版可以随时切回原文。复制、编辑、引用拿到的仍是原始文本，秘密信息依旧会被遮住。
- **插件面板不再闪、重名行能分清。** 面板式插件加载时不再反复闪 shimmer；标题相同的插件会在副标题里显示包名，方便分辨。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿），截图基线无变化；真机尚未完整验证。

### English

- **Markdown renders in your own messages.** Code blocks, headings and Markdown links pasted into chat are auto-detected and formatted in the bubble; you can switch back to raw text anytime. Copy, edit and quote still use the original text, and secrets stay masked.
- **Plugin panel no longer flickers; duplicate rows are distinguishable.** Panel islands no longer replay the shimmer on load; plugins sharing a title now show their package name as a subtitle.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green), with no golden-image changes; not yet fully verified on a real device.

## 1.2.11 · 2026-11-21

### 中文

- **可隐藏「登录 DeepSeek」提示。** 设置 › 外观新增开关；开启后，未登录且没有 API Key 时，设置首页不再显示登录行，改由本机引擎占用整张概览卡（图标、状态、DSH 版本更大更清楚）。已登录或已填 Key 时不受影响，开关默认关闭。
- **「关于」页品牌卡修正。** 卡片内的图标与文字改为真正居中，并与下方卡片留出间距（之前因为 Stack 的子部件没有撑满，整体贴在了左边）。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿），并重新生成了外观与关于页的截图基线；真机尚未完整验证。

### English

- **Hide the "Sign in to DeepSeek" prompt.** A new switch in Settings › Appearance: when on and the user is signed out with no API key, the settings hub replaces the sign-in row with a full overview card for the local engine (icon, status and DSH version in the large row). Signed-in users and API-key users are unaffected; the switch is off by default.
- **About page hero fixed.** The launcher tile and texts are now truly centred in the card, with breathing room before the card below (the old Stack child was shrink-wrapped and pinned everything left).
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green), and the Appearance/About golden images were regenerated; not yet fully verified on a real device.

## 1.2.10 · 2026-11-21

### 中文

- **「关于」页面按真机反馈收敛。** 去掉分组标题前的彩色圆点，所有行图标统一成中性线性图标，不再五颜六色；顶部品牌卡的两个信息胶囊改为居中，背景换成更明确的强调色晕染，整张卡片也更紧凑。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿），并重新生成了「关于」页截图基线；真机尚未完整验证。

### English

- **About page toned down after device feedback.** Removed the coloured dots before group headings, switched every row to one neutral line-icon style instead of a rainbow, centred the two chips in the brand hero and gave its wash a clearer accent tint in a tighter card.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green), and the About page golden images were regenerated; not yet fully verified on a real device.

## 1.2.9 · 2026-11-21

### 中文

- **插件名称与描述可一键翻译。** 在已安装插件和插件市场的详情页，名称和描述旁多了翻译按钮；界面为英文且原文含中文时才会出现。点按后通过免费翻译接口取回英文，同一段文本只请求一次，失败或断网时保留原文，不改动插件自己的元数据。
- **插件市场显示 README。** 详情页会从 npm 读取插件的 README，用 App 自带的 Markdown 渲染（表格、任务列表、代码块、图片、折叠块都支持），并把相对图片/链接指向插件仓库的默认分支。
- **「关于」页面重做。** 加了品牌卡片（启动图标、版本、fork 标记，配色跟随当前壁纸），分组标题带色点、每行配图标，页脚分隔更清楚。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿），并重新生成了「关于」页的截图基线；真机尚未完整验证。

### English

- **Translate plugin names and descriptions on demand.** Installed-plugin and market detail sheets now show a translate button beside the name and description, only when the UI is in English and the source contains Chinese. It fetches English through a free translation endpoint, caches each text, and keeps the original on failure or offline; plugin metadata itself is never rewritten.
- **Plugin READMEs in the market.** The detail sheet reads a plugin's README from npm and renders it with the app's own Markdown (tables, task lists, code blocks, images and collapsible sections), resolving relative links and images against the plugin repository's default branch.
- **About page refreshed.** A brand hero (launcher tile, version and fork chips, wallpaper-driven colours), tinted group headings, icons on every row and a clearer footer.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green), and the About page golden images were regenerated; not yet fully verified on a real device.

## 1.2.8 · 2026-11-20

### 中文

- **更新时可选本机其他安装器。** 安装包下载并校验完成后，更新面板会自动找出这台手机上所有能打开 APK 的应用（Morphe Manager、InstallerX、Mixplorer、Usagi 等），以按钮列出；点按即把同一个已校验的安装包交给该应用处理，安装仍需它自己确认。应用由 Android 的 intent 查询自动发现，新增安装器无需改代码。
- **同步上游。** 合入上游：酒馆续写 / 重试 / 切换分支时不再重播到场动画，以及按回合隔离的聊天图片快照修复（含相关测试）。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **Pick another installer on this phone when updating.** Once the APK is downloaded and verified, the update sheet discovers every app on this phone that can open an APK (Morphe Manager, InstallerX, Mixplorer, Usagi, ...) and lists them as buttons; tapping one hands the same verified package over to it, with installation still confirmed by that app. Apps are discovered through Android's intent resolution, so new installers need no code change.
- **Upstream sync.** Merged upstream: no replayed arrival animation on Tavern continue/retry/branch switches, and per-turn chat image snapshot fixes (with tests).
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.7 · 2026-11-20

### 中文

- **宠物交互回到上游原版。** 1.2.5–1.2.6 尝试让宠物站在每颗胶囊上、并改写拖拽的落点逻辑，但在真机上放开宠物时它会弹回原位；这三个改动整体回退，宠物层恢复为上游的版本（整行一个落脚点、拖拽沿整行自由移动），同时带入上游最近的宠物修复。
- **同步上游。** 合入上游：悬浮窗扇形菜单按自身行数重排等宠物修复，以及夜间的远端网页视图、会话备份、语音通话、后台保护等一批改动。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **The pet interaction is back to upstream's own.** The 1.2.5–1.2.6 attempts — standing on every capsule and a rewritten drag landing — made the pet snap back on release on a real device; all three are reverted wholesale, restoring the pet layer exactly as upstream ships it (one perch for the row, a drag free along it) and bringing in upstream's own recent pet fixes with it.
- **Upstream sync.** Merged upstream: the floating window's radial menu laid out by its own row count among other pet fixes, plus the overnight remote web view, session backup, voice call, and background protection changes.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.6 · 2026-11-20

### 中文

- **放开宠物后不再弹回右下角。** 位置原先是按所站胶囊自身宽度的比例保存的，而胶囊只有一百多像素宽、拖拽却能横跨整屏：比例一旦超过 1 就被夹到 1，松手时宠物便弹回那颗胶囊的右端（1.2.5 引入）。现在位置按整屏宽度的比例保存、再换算成脚下的位置，拖到哪里松手就停在哪里；脚下是空隙时落到最近的一颗胶囊上。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **Releasing the pet no longer snaps it back to the bottom-right.** Its position was stored as a share of the standing pill's own width, but a pill is barely a hundred px wide while a drag spans the whole screen: past a share of 1 it clamped to 1 and the pet jumped to that pill's right end (introduced in 1.2.5). The position is a share of the screen width now, converted to the foot per pill, so it stays where it is let go; over a gap it lands on the nearest pill.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.5 · 2026-11-20

### 中文

- **宠物拖拽自由了。** 按住宠物拖动时，它会沿着整行自由左右移动、跟着手指越过胶囊之间的间隙，不再被绑在拖动开始的那颗胶囊上；松手时落在脚下的胶囊上——脚在间隙里时落最近的一颗——永远不会落到空白处悬空。
- **同步上游。** 合入上游：远程网页视图、会话备份、语音通话、后台保护。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **The pet's drag is free.** While held, the pet slides freely along the row, following the finger across the gaps between the capsules instead of being tied to the pill the drag started on; on release it lands on the pill under its foot — the nearest one when the foot is over a gap — and never settles over empty space.
- **Upstream sync.** Merged upstream: the remote web view, session backup, voice call, and background protection.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.4 · 2026-11-19

### 中文

- **宠物踩在真的「积木」上。** 输入框上方的胶囊行（「完全权限」、插件入口等）之前整行只有一个落脚点，宠物走在行内的空档、或最后一颗胶囊之外时像悬在半空；现在每颗胶囊各自是一个落脚点：宠物站在某颗胶囊的顶边，胶囊消失时跳到最近的一颗，拖拽跨过边缘也会落到手指下的下一颗，不会再踩空。
- **同步上游。** 合入上游：酒馆 W7/W8 脚本库与 MVU、DNS 故障转移、凭据引用绑定、会话读取上限提到 64 MiB、分享链接的时钟可替换、profile 根目录安装优先级补丁。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **The pet stands on real blocks.** The capsule row above the composer (「Full access」, the plugins entry and the rest) used to be one full-width perch, so the pet hanging over its empty stretches — between the pills or past the last one — looked airborne; every pill is a perch of its own now: the pet stands on a pill's top edge, hops to the nearest one when its pill disappears, and a drag crossing a pill's edge lands on the neighbor under the finger instead of thin air.
- **Upstream sync.** Merged upstream: the Tavern W7/W8 script library and MVU, DNS failover, credential-reference binding, the session read cap raised to 64 MiB, a replaceable share-link clock, and the profile root installation precedence patch.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.3 · 2026-11-19

### 中文

- **深色主题下渠道图标清晰可见。** 「添加渠道」目录的图标大多按 `currentColor` 绘制（少数硬编码黑色），在深色主题里会沉进背景；现在黑色笔触统一映射为行内文字色、跟随主题明暗，带品牌色的图标保持原样——与 models.dev 网站在深色模式下的做法一致。
- **发送框的模型胶囊带上渠道名。** 输入框旁的模型胶囊先显示渠道名（加粗），模型名与思考档位随后（弱化），一眼能看出这条消息走的是哪个渠道；渠道显示名来自模型目录的渠道分组，没有分组信息时保持原样。
- **同步上游。** 合入上游修复：Android 10 的 Shell 辅助进程启动修复、PRoot 启动失败时建议改用 tawcroot（安全模式）、引擎恢复的测试补齐。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **Provider logos stay visible on dark theme.** Most logos in the Add provider catalogue paint `currentColor` (a few hard-code black), which sinks into the dark sheet; black paints now map to the row's text color and follow the theme, while logos with real brand colors keep theirs — the same way the models.dev site handles dark mode.
- **The composer's model pill shows the provider.** The pill beside the input now leads with the provider name (bold), the model name and thinking level following it (dimmed), so the route a message takes is clear at a glance; the display name comes from the model catalog's provider group, and without one the pill looks as before.
- **Upstream sync.** Merged upstream fixes: the Android 10 Shell helper startup fix, a suggestion to try tawcroot (safe mode) after a PRoot startup failure, and engine recovery tests.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.2 · 2026-11-19

### 中文

- **渠道目录可以滚动了。** 「添加渠道」的 models.dev 目录列表改成真正可滚动的列表：几百个渠道不再溢出弹层、不再盖住底部的说明和「自定义」按钮，滚动时行与行之间有细分隔线；弹层的搜索框、列表高度与底部按钮的间距也调顺了。
- **渠道图标不再因为搜索而串行。** 目录的图标按渠道 id 缓存：过滤列表时行会被复用，之前每次输入都会重新请求图标、还可能显示上一行的图标；现在每个渠道的图标只取一次、始终显示自己的。
- **获取模型自动带上模型能力。** 从目录预设的渠道获取模型时，接口列表没说的字段由 models.dev 补齐：显示名、上下文、输出上限、输入模态（文本 / 图片）和思考档位；接口自己报告的值优先。
- **预设来源不再被遮住。** 从目录选择预设后，表单上的「预设自 models.dev」一行移到 Basic info 卡片和 Connection 卡片之间，不再被卡片的玻璃背景盖住；「文档」按钮与字段对齐。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **The provider catalogue scrolls.** The models.dev list in Add provider is now a genuinely scrollable list: a few hundred providers no longer overflow the sheet or cover the credit line and the custom button, with a hairline between rows while scrolling; the sheet's search field, list height and footer spacing are tidied up.
- **Provider logos no longer scramble while searching.** Catalogue logos are cached by provider id: the lazy list recycles its rows while filtering, which used to refetch a logo on every keystroke and could show the previous row's logo; each provider's logo is now fetched once and always its own.
- **Fetched models carry their capabilities.** When fetching models for a catalogue preset, what the endpoint's listing leaves out is filled in from models.dev: display name, context window, output limit, input modalities (text / image) and the thinking levels; what the endpoint reports itself wins.
- **The preset note is no longer covered.** After picking a preset, the "Preset from models.dev" line on the form sits between the Basic info and Connection cards instead of under the card's glass, and its docs button lines up with the fields.
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.1 · 2026-11-18

### 中文

- **检查更新改到本仓库。** 应用内的更新检查与下载全部指向本 fork（`sang765/DSH-Go-Enhanced`）的 GitHub Releases，不再检查原仓库，也不会再提示安装原仓库的版本；默认不再使用原仓库的下载镜像。分享卡片、求 star 提示与社区内容仍指向原项目。
- **渠道目录。** 「设置 → 模型 → 添加渠道」新增从 models.dev 选择的目录：按名字搜索、显示官方 logo，选中后自动填好名称、协议与 Base URL，也可以照旧手动添加。
- **同步上游。** 合入上游 1.2.0：iOS 测试包、鸿蒙版合入主线、酒馆接口补齐、会话搜索（能搜到自己问过的话）、手机操控确认改三档、长回复分块渲染，以及一批修复（详见 1.2.0 一节）。
- **验证情况。** 改动通过 GitHub Actions 全量 CI（分析、测试、编译均绿）；真机尚未完整验证。

### English

- **Update checks moved to this repository.** In-app update checks and downloads now point at this fork's GitHub Releases (`sang765/DSH-Go-Enhanced`) instead of the original repository, and no longer offer the original repository's builds; the original repository's download mirror is no longer used by default. Share cards, the star prompt and community content still credit the original project.
- **Provider catalogue.** Settings → Models → Add provider gains a catalogue powered by models.dev: search by name with official logos, and picking one fills in the name, protocol and Base URL for you; manual entry is unchanged.
- **Upstream sync.** Merged upstream 1.2.0: the iOS test package, HarmonyOS on the main line, complete Tavern interfaces, chat search that finds your own questions, three-choice phone-control confirmation, block-wise rendering of long replies, and a batch of fixes (see the 1.2.0 section for details).
- **Testing.** The changes pass GitHub Actions' full CI (analysis, tests and builds all green); not yet fully verified on a real device.

## 1.2.0 · 2026-11-18

### 中文

- **iOS 版（测试）。** 这一版起提供未签名的 iOS 安装包 `dsh-go-1.2.0-ios-unsigned.ipa`，需要用爱思助手、AltStore 等工具自己签名后安装。用免费 Apple ID 签名时 Bundle ID 会被改掉，部分能力（如 Siri、分享扩展、后台）可能用不了。iOS 版只在少数真机上试过，问题请开 issue。
- **鸿蒙版合入主线。** 鸿蒙版的代码已经和安卓、iOS 共用一套，这一版暂时不提供 HAP 安装包，签名就绪后再补到这个版本下。
- **酒馆。** 酒馆助手的接口补齐，支持原生 MVU 变量；能把 DeepSeek 网页里聊不下去的对话导入酒馆接着聊；导入大卡和长聊天时明显不卡了。
- **让 AI 做一只宠物。** 宠物页新增「让 AI 做一只宠物」：带上自己的素材（GIF、逐帧图、Aseprite 导出或单张图），AI 会把它转成宠物包；转换时保留中文动画名，网页模式也能用。
- **按你问过的话搜索会话。** 会话搜索能搜到你自己问过的话和回复摘要，句子中间的中文词也能搜到。
- **手机操控确认改成三档**：允许一次、本轮允许、取消；设置里可以列一份「始终允许」的 App。停止只作用于当前这一轮，下一轮自动恢复。免确认模式下截图和点击不再弹卡。
- **长回复更流畅。** 长回复分块显示，流式输出时只重排最后一块。
- 其他改进：选 English 时 App 写给引擎的 AGENTS.md 也用英文；伙伴包的大小上限放宽，投稿失败会说清原因；桌面小组件的默认文字跟随 App 语言；跳过的版本换了更新源后也算跳过。
- **修复。** 安卓引擎在某些情况下重启被锁死；DeepSeek 的拒绝回复和无名错误被当成网络错误；生成图片时网关返回空链接导致图片丢失；首次 DNS 失败占用当天的生成额度；回合结束但没有答复时没有任何提示；Windows 主机的盘符路径和链接打不开、长文件名存不到手机；换启动画面或壁纸时旧文件被提前删掉；快速切换主机后最近会话停在上一个；未发出的草稿丢失；读屏无法点击详情页签和主题选项。
- **fork 独立身份。** 包名改为 `io.github.sang765.dsh_app_enhanced`，可与原版并存安装；配置正式发布签名；关于页新增 fork 署名，指向本仓库。
- **数据迁移。** 新增「导入 DSH Go 数据」：旧应用里一条命令把引擎数据打包到共享存储，本应用选择文件后并入对话、工作区文件、长期记忆、插件与引擎设置；导入时引擎先停止，完成后自动重启。应用设置与 API Key 不随导出，需要重新配置。
- **验证情况。** iOS 版和鸿蒙版都只在 CI 里编译并跑过模拟器测试，真机只做过零星试用；安卓版的新改动大部分只经过自动测试。遇到问题请导出诊断并开 issue。
- **验证情况。** 改动通过 GitHub Actions 的全量 CI（分析、测试、编译均绿）；真机尚未完整验证。遇到问题请导出诊断并开 issue。

### English

- **iOS (testing).** Starting with this version there is an unsigned iOS package, `dsh-go-1.2.0-ios-unsigned.ipa`, which you sign yourself with a tool such as AltStore before installing. Signing with a free Apple ID changes the bundle ID, and some features (such as Siri, the share extension and background work) may not be available. The iOS version has only been tried on a few real devices; please open an issue if something goes wrong.
- **HarmonyOS joins the main line.** The HarmonyOS code now shares one code base with Android and iOS. This version doesn't ship a HAP yet; it will be added to this release once signing is ready.
- **Tavern.** The Tavern Helper interfaces are complete, with native MVU variables; conversations that ran out of room on the DeepSeek website can be imported into Tavern and continued; importing large cards and long chats no longer stutters.
- **Have the AI make a pet.** The pets page has a new Have the AI make a pet entry: bring your own art (GIFs, frame sequences, Aseprite exports or a single image) and the AI turns it into a pet pack; Chinese animation names are kept, and it works in web mode too.
- **Search chats by what you asked.** Chat search finds your own questions and reply summaries, including Chinese words in the middle of a sentence.
- **Phone control confirmation has three choices**: allow once, allow for this turn, or cancel, and Settings can keep a list of always-allowed apps. Stop only applies to the current turn; the next turn starts fresh. Screenshots and taps no longer show a card when confirmation is off.
- **Smoother long replies.** Long replies are rendered in blocks, and while streaming only the last block is laid out again.
- Other improvements: with English selected, the AGENTS.md the app writes for the engine is in English too; companion pack size limits are looser and failed submissions say why; the home screen widget's default text follows the app language; a skipped version stays skipped after switching update source.
- **Fixes.** The Android engine getting stuck on restart in some cases; DeepSeek refusals and unnamed errors being reported as network errors; images lost when the gateway returned an empty link; a first DNS failure using up the day's generation budget; no notice when a turn ended without an answer; drive-letter paths and links from Windows hosts not opening, and long file names not saving to the phone; the old file being deleted too early when changing the launch screen or wallpaper; recent chats sticking to the previous host after switching quickly; unsent drafts being lost; screen readers not being able to tap detail tabs and theme options.
- **Fork identity.** The package name is `io.github.sang765.dsh_app_enhanced`, so it installs alongside the original; the release is signed with the production key; the About page credits the fork and links this repository.
- **Data migration.** A new "Import DSH Go data" flow: in the old app one command packs the engine data to shared storage, and this app merges it — conversations, workspace files, long-term memory, plugins and engine settings; the engine stops first and restarts when done. App settings and API keys are not exported and need reconfiguring.
- **Testing.** The iOS and HarmonyOS versions have only been compiled and run on simulators in CI, with only occasional tries on real devices; most of the new Android changes have only been checked by automated tests. If you run into a problem, please export diagnostics and open an issue.
- **Verification.** The changes pass GitHub Actions' full CI (analysis, tests, builds all green); not yet fully verified on a real device. If something breaks, please export diagnostics and open an issue.

## 1.1.0 · 2026-11-15

### 中文

- **语音：朗读、语音输入和语音通话。** 回复可以用 DeepSeek 的声音朗读，输入框可以说话输入，也可以直接和她语音通话。通话里能随时打断她，她会自己判断你说完了再接话，有实时字幕；「停顿多久算说完」可以选，默认多等一会儿。通话中可以换声音和识别方式。用账号登录时语音接口不认账号，会改用 API Key。
- **酒馆：玩法包和做卡工具。** 新增玩法包；做卡时可以让 AI 改卡、挑着应用改动、看历史版本、看最终提示词，还能先试玩。长对话不再越聊越卡（显示、用量统计、读对话都快了很多）。支持工具回合和自定义模型渠道，数值可以手填；回复长到顶栏下面时顶栏会加遮罩。
- **手机操控：悬浮条和不打扰模式。** 操控时屏幕边缘换成柔和的色带；悬浮条可以拖动、贴边，小球闲置时半藏在边上。不打扰模式选好通道、连上就能用，不再被一整套准入检查拦住；主屏读不到当前应用时改成确认一次，不再直接拒绝。
- **使用统计 v3。** 新增酒馆、伙伴小屋、语音通话和 token 用量。
- **桌宠更活泼。** 反应有多种动画，彩蛋在各种状态下都能触发，新增「搬东西」动作。
- 其他新功能：创意工坊的投稿改用 GitHub 账号登录，默认连接 go.dshtui.com；自定义启动画面在填满模式下可以缩放和调整位置；新增九个界面特效。
- **修复。** 进语音通话闪退；发给模型的内部提示不再出现在对话里；远程连接点「重连」立刻重连；伙伴小屋在旧版系统 WebView 上打不开、记忆保存的回包丢了列表不刷新；悬浮宠物在系统重新允许动画后不动；从系统设置打开实时活动回来后不补发；自动检查更新时中途关掉仍弹更新页；深色模式下分段选择器的滑块看不见；子代理都停了标题栏的忙碌点还在转；DeepSeek 图片附件丢失被当成网络错误。引擎运行时的 proot 升到 5.1.107.102（主要是硬链接模拟的修复）。
- **验证情况。** 语音、悬浮条、不打扰模式和 proot 升级只在自动测试和编译检查里验证过，没有在真机上完整走过。遇到问题请导出诊断并开 issue。

### English

- **Voice: read aloud, voice input and voice calls.** Replies can be read aloud in DeepSeek's voice, you can dictate in the input box, or call her directly. During a call you can interrupt her at any time; she works out when you've finished before answering, with live captions. How long a pause counts as finished is adjustable and defaults to waiting a little longer. You can change the voice and the recognition method mid-call. When signed in with an account the speech service won't accept, it falls back to your API key.
- **Tavern: play packs and card authoring.** Play packs are new. While making a card you can have the AI revise it, pick which changes to apply, browse past versions, see the final prompt and try it out first. Long chats no longer slow down as they grow (display, usage and loading are all much faster). Tool turns and custom model providers are supported, numbers can be typed in, and the top bar gets a scrim when a long reply scrolls under it.
- **Phone control: overlay bar and Do Not Disturb.** The screen edge shows a soft band while the app is in control; the overlay bar can be dragged and docked to an edge, and the ball tucks half away when idle. Do Not Disturb works as soon as a channel is chosen and connected, without the old admission checks; when the home screen can't tell which app is in front, it asks you once instead of refusing.
- **Usage stats v3.** Adds Tavern, the companion room, voice calls and token usage.
- **Livelier pets.** Reactions have several animations, easter eggs trigger in every state, and there's a new carrying action.
- Other new features: Creative Workshop submissions now sign in with GitHub, and the workshop connects to go.dshtui.com by default; a custom launch screen in fill mode can be zoomed and repositioned; nine new interface effects.
- **Fixes.** A crash on entering a voice call; internal notes meant for the model no longer show up in the chat; Reconnect for remote connections reconnects right away; the companion room failing to open on older system WebViews, and its memory list not refreshing when a save reply was lost; the floating pet staying still after the system re-enables animations; the live activity not being re-posted after returning from system settings; the update page still appearing when an automatic check was turned off midway; the segmented control's thumb vanishing in dark mode; the busy dot in the title bar spinning after all sub-agents had stopped; a lost DeepSeek image attachment being reported as a network error. The engine runtime's proot is now 5.1.107.102 (mostly fixes to hard-link emulation).
- **Testing.** Voice, the overlay bar, Do Not Disturb and the proot update have only been checked by automated tests and builds, not fully on a real phone. If you run into a problem, please export diagnostics and open an issue.

## 1.0.16 · 2026-11-13

### 中文

- **酒馆：新的角色扮演模式。** 抽屉顶栏的「模式」键可以在工作、伙伴、酒馆之间切换，设置 › 界面 › 启动时进入可以选默认进哪个。兼容 SillyTavern 的角色卡、预设、世界书、正则和聊天记录：导入卡（文件、分享、卡站链接）或自己写一张；对话有气泡、小说、视觉小说三种排版，支持备选、接着写、帮我写、分支和书签；资源库里管理预设、世界书、正则、人设和快速回复。消息里的 HTML 在隔离的网页里显示，相关安全开关默认关。
- **创意工坊。** 宠物设置和伙伴小屋的菜单里多了「创意工坊」：浏览、安装大家做的像素宠物和伙伴，不用登录；也可以投稿自己做的，先审后发，有问题的作品可以举报。投稿、查看自己的投稿和举报要用论坛账号，第一次会先说明会把什么发给工坊服务，同意后才发。
- **悬浮伙伴。** 宠物的「App 外显示」可以选「小屋里的她」，让伙伴小屋的角色待在悬浮窗里。悬浮窗里点一下是互动，连点两下才打开对话（像素宠物也改成这样）；伙伴小屋会跟着手机倾斜和摇晃动。悬浮伙伴比像素宠物更耗电。
- **tawcroot 加速启动（实验，默认关）。** 在 诊断 › 开发者选项 里打开后，本机引擎改用 tawcroot 启动：在测试手机上启动从约 5 秒降到约 1.5 秒，装包和 apt 也更快。起不来时自动改用原来的方式，不算启动失败；和「直接启动」二选一。关掉后的第一次启动会先把它留下的文件整理一遍。
- **超长工具输出只显示头尾。** 几万行的命令输出不再把对话卡住：中间折叠，点「查看全部」在单独的页面里看全文，可以跳到开头或末尾、复制全部。
- **酒馆后续：群聊和整页画布。** 可以建群聊，按发言人轮流，视觉小说按说话人换舞台。整页画布（酒馆设置里试用，默认关）能在隔离的网页里跑卡自带的 HTML 和脚本，兼容酒馆助手常用的接口；卡脚本要你输入或选按钮时用 App 自己的对话框。舞台面板可以播放卡里的音乐。每条回复显示按 DeepSeek 官方价估算的费用（高峰、低谷分开，节假日会算高一点），可以设单回合费用提醒，默认关。
- **手机操控：后台屏和 Shell 连接能自己恢复。** 第一次连接失败后不再一直不可用，App 升级后不再复用旧服务；后台资源残留时也能完成释放，不再永久卡住（#1096、#1104）。手机操控页精简了：只显示当前缺的权限或连接步骤，Root、Sui 这类不常用的项需要时再展开，自检改成单独一页。
- 其他新功能：可以删除已归档的会话；已安装插件可以筛选；自定义渠道支持自定义请求头（也用于模型发现）；SSH 主机支持认证后压缩和连接已有实例；更新窗口可以导出已下载的安装包，给需要自己重签的手机兜底；Shizuku 和本机 ADB 可以直接完成自更新；新对话首页的建议可以关掉。
- **大量稳定性修复。** 这一版合入了一百多处运行时、桥接、媒体和更新流程的修复，主要是：直接启动模式下会话、附件、媒体和文件的落盘；磁盘满时的提示和恢复；请求中途断开、进程被杀后的恢复；日志和诊断包里的凭据打码；更新下载被重定向到另一个域名后超时不生效；带「保留」的重置不再丢掉硬链接过的文件内容。聊天、终端、插件、设置和无障碍另有约六十处修复。后来又合进一批：定时任务里「每月倒数第 N 个某天」「每周第 N 个工作日」和普通星期、序数星期混写时算错日期；Web 斜杠菜单里技能消失、改了默认预设后第一条消息仍用旧预设、Web 搜索 key 保存失败却当成功；进程中途被杀留下的空锁、空标记和自更新残留；开着 tawcroot 时升级引擎误报不兼容。
- **验证情况。** 较早的一版测试包在一台手机（vivo X200 Pro，Android 16）上跑过一遍主要功能；之后合进来的后台屏连接重写、资源释放、酒馆群聊和整页画布，以及上面最后那批修复，没有在真机上验证过。大部分修复只经过自动测试和编译检查；直接启动在部分手机上（包括这台）仍会被系统拦下，届时自动改用兼容启动。遇到问题请导出诊断并开 issue。

### English

- **Tavern: a new role-play mode.** The Mode button in the drawer's top bar switches between Work, Companion and Tavern, and Settings › Interface › Open on start picks the default. It is compatible with SillyTavern character cards, presets, lorebooks, regex scripts and chat logs: import a card (file, share or card-site link) or write your own. Chats can be laid out as bubbles, a novel or a visual novel, with alternatives, continue, write-for-me, branches and bookmarks. The library manages presets, lorebooks, regex, personas and quick replies. HTML inside messages is shown in an isolated web view, and the related safety switches are off by default.
- **Creative Workshop.** Pet settings and the companion room's menu now have Creative Workshop: browse and install pixel pets and companions others made, with no sign-in needed, or submit your own. Submissions are reviewed before they appear, and you can report a problem item. Submitting, viewing your submissions and reporting use your forum account; the first time, the app explains what it will send to the workshop service and only sends it after you agree.
- **Floating companion.** A pet's Show outside the app can now be set to the companion from the room, so she stays in the floating window. In the floating window a single tap interacts and a double tap opens the chat (pixel pets work the same way now). The companion room also reacts to tilting and shaking the phone. The floating companion uses more battery than a pixel pet.
- **tawcroot fast launch (experimental, off by default).** Turn it on under Diagnostics › Developer options and the local engine starts with tawcroot: on the test phone, startup went from about 5 seconds to about 1.5, and package installs and apt are faster too. If it can't start, the app falls back to the usual method, which doesn't count as a start failure. Only one of it and direct launch can be on. The first start after turning it off tidies up the files it left behind.
- **Very long tool output shows only its start and end.** Command output tens of thousands of lines long no longer bogs the chat down: the middle is folded, and View all opens the full text on its own page, where you can jump to the start or end and copy everything.
- **More Tavern: group chats and the full-page canvas.** You can start a group chat with speakers taking turns, and the visual novel layout changes the stage with the speaker. The full-page canvas (a trial switch in Tavern settings, off by default) runs a card's own HTML and scripts in an isolated web view and supports the Tavern Helper interfaces cards commonly use; when a card script asks you for input or a button, the app's own dialogs handle it. The stage panel can play a card's music. Each reply shows an estimated cost at DeepSeek's official prices (peak and off-peak priced separately; public holidays come out a little high), and you can set a per-turn cost alert, off by default.
- **Phone control: the background screen and Shell connection recover on their own.** A first failed connection no longer leaves them unavailable, and an app update no longer reuses the old service. Leftover background resources can now be released instead of staying stuck (#1096, #1104). The phone control page is simpler: it shows only the permission or connection step that is missing, rarely used items such as Root and Sui expand when needed, and the self-check has its own page.
- Other new features: archived chats can be deleted; installed plugins can be filtered; custom providers support custom request headers, also used for model discovery; SSH hosts support compression after authentication and connecting to an existing instance; the update sheet can export the downloaded package as a fallback for phones that need to re-sign it themselves; Shizuku and local ADB can complete self-updates directly; the suggestions on the new-chat start page can be turned off.
- **Many stability fixes.** This version brings in over a hundred fixes to the runtime, bridge, media and update flow, mainly: how sessions, attachments, media and files are written in direct launch mode; messages and recovery when storage is full; recovery after a request is cut off or the process is killed; masking credentials in logs and diagnostics; the timeout not applying after an update download is redirected to another domain; and a reset that keeps your files no longer losing the contents of hard-linked files. Chat, terminal, plugins, settings and accessibility get about sixty more fixes. A later batch adds: scheduled tasks computing wrong dates for rules like the last-but-N weekday of a month, the Nth workday of a week, or plain and numbered weekdays mixed; skills vanishing from the web slash menu, the first message after changing the default preset still using the old one, and a failed web search key save being treated as success; empty locks, empty markers and self-update leftovers when the process is killed midway; and a false incompatibility report when upgrading the engine with tawcroot on.
- **How this version was checked.** An earlier test build went through the main features on one phone (vivo X200 Pro, Android 16). What was merged after it, the rewritten background screen connection, resource release, Tavern group chats and the full-page canvas, and the last batch of fixes above, hasn't been tried on a real phone. Most fixes have only been through automated tests and compile checks. Direct launch is still blocked by the system on some phones (including that one), and the app then falls back to compatible launch. If you hit a problem, please export diagnostics and open an issue.

## 1.0.15 · 2026-11-10

### 中文

- **从这一版起，更新引擎不再清空 Linux 环境。** 这次运行时又有改动，所以还是下整包；但更新时只替换 App 管理的引擎部分（DSH、Node、pnpm、桥接和它们的目录），用 `apt` 装的工具、默认位置的 npm 全局包、Python / pip 包、配置和工作区都会保留。从 1.0.14 升上来就生效。Node 版本变了时，第三方原生扩展仍可能要重新编译。
- **如果更新停下来了，先别重置。** App 确认不了现有环境和新引擎兼容、更新清单损坏，或者旧进程没停干净时，会停止更新并说明原因，原环境原样保留。按提示重试；还不行就导出诊断并开 issue，不要重置环境或卸载 App。
- **匿名使用统计多报两项：手机型号和厂商系统版本。** 型号是系统给的代号（如 `V2405A`），系统版本如 OriginOS 5.0、HyperOS 2.0，用来看问题集中在哪些机型和系统上。不含序列号、Android ID 这类能认出某一台手机的信息，仍可在「隐私与分享」里关掉。
- **这一版没有在真机上验证过。** 上面这套保留环境的更新流程和扫码配对只经过自动测试和编译检查。遇到问题请开 issue 反馈。
- 扫码配对电脑：修好相机打不开、从相册识码报 `MlKitContext has not been initialized` 的问题（#802）。扫码前会按需准备 ML Kit，不需要打开手机操控的「本机文字识别」，也不会改它的开关；SDK 出错和图里没有二维码会分开提示。
- 引擎和运行环境：上一次启动迟到的日志不再混进这次的故障快照和诊断；停止和自动安全模式同时发生时，状态不会被旧的「正在停止」盖回去；停止后迟到的刷新不会把已撤掉的前台通知发回来；持久终端的就绪判断不再受系统时间跳变影响。
- 通知和视频：审批点过、结果还没回来时重发的通知保留你的决定，显示「正在处理」，不再给按钮；上一次申请迟到的失焦回调不会再暂停刚恢复的视频。
- 其他修复：永久删除对话时一并删掉迁移留下的临时正文；最近会话的桌面快捷方式迁移失败时保留旧入口，下次再试（#22）；Agent Team 冷恢复时，子 agent 已领取的初始输入不再被判失败（实验功能）。

### English

- **From this version on, updating the engine no longer wipes the Linux environment.** The runtime changed again, so this is still a full download, but an update now replaces only the engine parts the app manages (DSH, Node, pnpm, the bridge and their folders). Tools installed with `apt`, npm global packages in the default location, Python and pip packages, configuration and workspaces are kept. This already applies when updating from 1.0.14. When the Node version changes, third-party native extensions may still need rebuilding.
- **If the update stops, don't reset.** When the app can't confirm the existing environment works with the new engine, the update manifest is damaged, or old processes haven't stopped, it stops the update, says why and leaves the environment as it was. Retry as it suggests; if it still fails, export diagnostics and open an issue rather than resetting the environment or uninstalling the app.
- **Anonymous usage stats now include two more items: the phone model and the maker's system version.** The model is the code the system reports (such as `V2405A`), and the system version is something like OriginOS 5.0 or HyperOS 2.0; they show which phones and systems problems cluster on. Nothing that identifies a single phone, such as a serial number or Android ID, is included, and you can still turn the stats off in Privacy and sharing.
- **This version hasn't been verified on a real phone.** The update flow that keeps the environment and pairing by scanning have only been through automated tests and compile checks. If you hit a problem, please open an issue.
- Pair a computer by scanning: fixed the camera not opening and gallery scans failing with `MlKitContext has not been initialized` (#802). ML Kit is prepared on demand before scanning; you don't need to turn on the phone control's on-device text recognition, and its switch isn't changed. An SDK failure and an image with no QR code are now reported differently.
- Engine and runtime: late log lines from the previous start no longer end up in this start's failure snapshot and diagnostics. When stopping and automatic safe mode happen together, an old Stopping state no longer overwrites the current one. A late refresh after stopping no longer brings back a foreground notification that was already removed. The persistent terminal's readiness checks are no longer thrown off by the system clock jumping.
- Notifications and video: a notification re-sent after you answered an approval but before the result came back keeps your decision and shows Processing, with no buttons. A late focus-loss callback from an earlier request no longer pauses a video you just resumed.
- Other fixes: deleting a chat for good also removes the temporary text left by migration. If moving the recent-chat home screen shortcuts fails, the old entry stays and it tries again later (#22). In Agent Team cold recovery, initial input a sub-agent had already taken is no longer marked failed (experimental feature).

## 1.0.14 · 2026-11-09

### 中文

- **更新前请注意：这一版的运行时有更新，所以还是下整包。** 内置引擎仍是 DSH 0.2.2-rc.1，变的是我们给它打的补丁和桥接层。升级后 Linux 环境里只保留 `/root`，用 `apt` 装的软件和放在 `/usr/local`、`/opt` 等目录的文件需要重新装。对话和设置不受影响。
- **这一版没有在真机上验证过。** 后台屏实时预览、多个后台任务、按截图坐标操作、本机文字识别、扫码配对和伙伴小屋的新功能都只经过自动测试和编译检查。遇到问题请开 issue 反馈。
- **新权限和新组件：** App 新声明了相机权限，只在扫码配对电脑时用；不给权限也可以从相册识图或粘贴配对链接。手机操控内置了 Google ML Kit 中文文字识别，默认开启：识别在手机上完成，截图和文字不会发给 Google，但 Google 的 SDK 会收集机型、应用版本、耗时等使用统计。不想要可以在手机操控页或「隐私与分享」里关掉「本机文字识别（ML Kit）」，关掉后不会加载它。
- 手机操控 · 多任务：每个对话的手机任务各自批准、暂停、停止。后台任务最多可以同时跑 3 个，在「不打扰模式」页的「后台任务上限」里设置，默认 1 个。悬浮条和通知上的停止、暂停、插话只作用于显示时的那个任务。
- 手机操控 · 看和点：「不打扰模式」页可以打开「实时查看后台屏」（默认关），App 内和悬浮小窗都能看，只读，最多每秒 5 帧，画面不存盘。找不到控件时可以按截图坐标点击、长按和滑动：截图 30 秒内有效，窗口一切换就作废；同一任务里第一次这样操作某个应用要你许可，发送、支付、删除仍然每次确认。输入文字后会回读核对，对不上时如实报告。
- 手机操控 · 技能和自检：任务成功后可以「存成技能」，起草时去掉联系人、号码、消息正文等个人信息，先预览、可修改，再装成 DSH 技能。手机操控页加了本机自检。
- 伙伴小屋 · 鲸鱼娘：她现在随 App 一起装好，第一次进小屋时自动安置，不用再自己导入素材包。模型作者是 B 站「Mao绒绒家园」，经作者授权随 DSH Go 分发。
- 伙伴小屋：菜单里的「主动邀请」换成「她多主动」，分安静、偶尔（默认）、常常、话多四档；别的对话跑完或出错时她提不提，在「她会提起什么」里分项开关。批准卡、提问卡和聊天记录在小屋里就能处理和翻看。日期、名字这些上下文不再写进你发出的消息里。完整模式可以打开自动想起记忆。
- 伙伴小屋 · 导入模型：模型文件夹直接打成 zip 也能导入。模型自带的表情和动作能用了，可以在菜单「动作和表情」里试、起名、标成 AI 可以用。蒙版多的精细模型也能画对，旧手机上更流畅；导不了的旧模型会说清原因。缺适配的模型可以让你配好的 AI 帮她适配：只发参数名单，不发模型文件，可以撤销，也可以关掉自动适配。
- 宠物：宠物选择里可以导入自己的像素宠物包，也能导入 Codex 宠物，转换后和原来不一样的地方会说明；长按自己导入的宠物可以删掉。
- 远程：Remote 电脑上也能开终端，电脑上关了终端时会提示去哪里打开；会话「文件」页可以直接「传文件到电脑」。「扫码配对电脑」要等 Remote 服务器支持后入口才会出现，线上服务器目前还没开。
- 诊断：诊断页可以在你逐次确认后采集系统输入法日志，帮助排查键盘自己收起的问题（#366）。只保留白名单里的事件，不记录输入内容和候选词。
- 网页版：关掉「手机布局」看官方网页版时，标题行左边的返回按钮换成 App 标记（点它仍是返回），DSH Web 侧栏打开时自动让开；系统返回会先收起官方侧栏。
- 其他修复：文件名清理后只剩空白时改用 `file`，上传不再被拒；宠物语音草稿和剪贴板预览截短时不拆开表情；锁屏时审批和分组摘要通知只显示公共标题；系统语音初始化失败后，下一次会重新创建；无障碍服务销毁后，迟到的连接不再重建悬浮层；远程主机换连接后，打开着的文件预览继续刷新（#465）；重新解包运行环境时补上 Android 附加组的组名（#159）。

### English

- **Before you update: this version changes the runtime, so it's a full download again.** The built-in engine is still DSH 0.2.2-rc.1; what changed are the patches we apply to it and the bridge layer. Only `/root` stays in the Linux environment, so software installed with `apt` and files in `/usr/local`, `/opt` and similar places need installing again. Chats and settings are kept.
- **This version hasn't been verified on a real phone.** Live background preview, multiple background tasks, actions by screenshot coordinates, on-device text recognition, pairing by scanning and the new companion room features have only been through automated tests and compile checks. If you hit a problem, please open an issue.
- **New permission and new component:** the app now declares the camera permission, used only to scan when pairing a computer; without it you can still read the code from a gallery image or paste the pairing link. Phone control now bundles Google ML Kit Chinese text recognition, on by default. Recognition runs on the phone and screenshots and text are not sent to Google, but Google's SDK collects usage statistics such as device model, app version and timing. If you don't want it, turn off On-device text recognition (ML Kit) on the phone control page or in Privacy and sharing; once off, it isn't loaded.
- Phone control, multiple tasks: each chat's phone task is approved, paused and stopped on its own. Up to 3 background tasks can run at once; set it under Background task limit on the Non-disruptive mode page (default 1). Stop, pause and interject on the floating bar and the notification act only on the task they were showing.
- Phone control, seeing and tapping: on the Non-disruptive mode page you can turn on Live background preview (off by default) to watch the background screen in the app or in a small floating window. It's view-only, at most 5 frames a second, and frames aren't saved. When no control can be found, the agent can tap, long-press and swipe by screenshot coordinates: a screenshot is valid for 30 seconds and is dropped as soon as the window changes. The first such action on an app within a task asks you; sending, paying and deleting still ask every time. Typed text is read back, and a mismatch is reported as it is.
- Phone control, skills and self-check: after a task succeeds you can Save as a skill. The draft leaves out contacts, numbers, message text and other personal details, and you can preview and edit it before it's installed as a DSH skill. The phone control page has a local self-check.
- Companion room, the whale girl: she now comes with the app and settles in the first time you open the room, so there's no pack to import. The model is by Mao绒绒家园 on Bilibili and is distributed with DSH Go with the author's permission.
- Companion room: the menu's invitation switch is now How often she speaks up, with four levels: Quiet, Now and then (default), Often and Chatty. Whether she mentions another chat finishing or failing is set item by item under What she brings up. Approval cards, question cards and the chat history can be handled and read right in the room. Context such as the date and your name is no longer written into the messages you send. Full mode can turn on automatic memory recall.
- Companion room, importing models: a zipped model folder can be imported as is. A model's own expressions and motions now work; try them, name them and mark them as usable by the AI under Moves and faces in the menu. Detailed models with many masks draw correctly, older phones run smoother, and an old model that can't be imported says why. A model that needs fitting can be adapted by the AI you configured: only the parameter list is sent, never the model files, and you can undo it or turn automatic fitting off.
- Pets: the pet picker can import your own pixel pet pack, and Codex pets too, with a note on anything that came out different from the original. Long-press a pet you imported to delete it.
- Remote: you can open a terminal on a Remote computer (if terminals are turned off on the computer, the app says where to turn them on), and a session's Files page can Send files to the computer directly. Pair a computer by scanning only appears once the Remote server supports it; the public server hasn't turned it on yet.
- Diagnostics: after you confirm each time, the diagnostics page can collect system keyboard logs to help track down the keyboard closing on its own (#366). Only allowlisted events are kept; typed text and suggestions are never recorded.
- Web: with the phone layout off on the official web page, the back button at the left of the title row is now the app mark (tapping it still goes back), and it moves out of the way when the DSH Web sidebar opens. System back closes the official sidebar first.
- Other fixes: a file name left blank after cleaning falls back to `file`, so uploads are no longer refused. Pet voice drafts and clipboard previews no longer split emoji when shortened. On the lock screen, approval and grouped summary notifications show only a public title. System text-to-speech is created again after it failed to start. A late connection to an accessibility service that was already destroyed no longer rebuilds the overlay. Open file previews keep refreshing after the remote host switches connections (#465). Unpacking the runtime environment again restores the group names for Android's supplementary groups (#159).

## 1.0.13 · 2026-11-08

### 中文

- **更新前请注意：这一版的运行时有更新，所以还是下整包。** 内置引擎仍是 DSH 0.2.2-rc.1，变的是我们给它打的补丁。升级后 Linux 环境里只保留 `/root`，用 `apt` 装的软件和放在 `/usr/local`、`/opt` 等目录的文件需要重新装。对话和设置不受影响。
- **这一版没有在真机上验证过。** App 内的视频播放和存视频到相册只经过自动测试和编译检查，没在手机上放过。遇到问题请开 issue 反馈。
- 新对话首页：建议换成横排小卡片，下面一行小技巧会自动轮换，点一下换下一条。首页就能选这次对话的模型、Agent 预设和权限，第一条消息发出前生效；设置失败时消息不会发出，留在输入框里。
- 视频：点视频在 App 内播放，可以播放、暂停和拖动进度，放不了时仍能用其他应用打开；视频也能保存到相册。没有封面的本机视频会取首帧当封面，远程视频只在你主动打开时才下载。
- 图片：加载失败时可以点「重新加载」，只重新读取文件，不会重新生成，也不会再收生成费用。
- 图像与视频设置：API 地址填根地址，编辑时可以预览请求地址；换站点或跨站点复用 Key 要先确认。「检查已保存配置」只检查配置本身，不联网验证 Key、余额或模型权限。
- 计划模式：重新打开对话后恢复之前选的计划模式，后面的命令失败也不会把它清掉。
- 手机操控：停止或换任务后，旧任务不会再启动应用、按键、点击或滚动；后台屏画面过期时会拒绝操作并要求刷新；横向列表的手势方向不再反；太短的滑动直接拒绝；所选模式和实际的 Shizuku / Sui 不一致时不再报就绪，并说明原因。
- 远程：迟到的退出登录不会再删掉新登录的凭据，旧的登录动作不会切到你后来选的服务器；自建服务器邮箱登录时连按完成键不再重复提交；较大的设置写入不再执行两次。
- 引擎：启动失败时先显示正在停止，并优先显示这次的原因；引擎服务没就绪不再被说成版本不支持；运行环境安装失败页可以直接导出诊断包；工作区索引损坏时可以改用独立的救援索引；插件安装输出里的中文和 emoji 不再乱码（#658）；空闲时排队的通知不再挡住永久删除对话（#687）；坏掉的 Agent 预设会显示实际的加载失败原因（#75）。
- 运行环境：重置前确认相关进程都已退出；升级中途被打断时保留要带走的用户文件。安全模式移走危险文件只完成一部分时会如实报告，可以重试剩下的。
- 文件和分享：很长的文件名按字节截短，不会切开表情，也保留扩展名。
- 插件开发：插件省略能力参数时按 v1 的默认处理，不再当成空列表（#656）。

### English

- **Before you update: this version changes the runtime, so it's a full download again.** The built-in engine is still DSH 0.2.2-rc.1; what changed are the patches we apply to it. Only `/root` stays in the Linux environment, so software installed with `apt` and files in `/usr/local`, `/opt` and similar places need installing again. Chats and settings are kept.
- **This version hasn't been verified on a real phone.** In-app video playback and saving videos to the gallery have only been through automated tests and compile checks, never played on a phone. If you hit a problem, please open an issue.
- New chat page: suggestions are now small cards side by side, with a tip line below that changes on its own; tap it for the next tip. You can pick this chat's model, Agent preset and permissions right on the page; they apply before the first message is sent, and if applying them fails the message stays in the composer instead of going out.
- Video: tap a video to play it in the app, with play, pause and seeking; if it won't play you can still open it in another app. Videos can be saved to the gallery too. A local video with no poster uses its first frame; a remote video is downloaded only when you open it.
- Images: when an image fails to load you can tap Reload. It only reads the file again; it doesn't regenerate or charge for generation again.
- Image and video settings: enter the API root as the address, and preview the request address while editing. Switching sites or reusing a key across sites asks first. Check saved configuration checks only the configuration; it doesn't go online to verify the key, balance or model access.
- Plan mode: reopening a chat restores the plan mode you chose, and a later command failing no longer clears it.
- Phone control: once a task stops or is replaced, the old one no longer launches apps, presses keys, taps or scrolls. Actions on a stale background screen are refused with a request to refresh. Gestures on horizontal lists no longer go the wrong way, swipes too short to register are refused, and when the selected mode doesn't match the actual Shizuku or Sui provider it no longer reports ready and says why.
- Remote: a late sign-out no longer deletes the credentials of a newer sign-in, and an old sign-in action no longer switches to a server you picked later. Pressing Done repeatedly while signing in by email on a self-hosted server no longer submits twice, and large settings writes no longer run twice.
- Engine: a failed start shows that it's stopping first and puts this attempt's reason ahead of older failures. An engine service that isn't ready is no longer reported as an unsupported version. The runtime install failure page can export a diagnostics bundle directly. A damaged workspace index can be swapped for a separate rescue index. Chinese and emoji in plugin install output are no longer garbled (#658). Notifications queued while idle no longer block deleting a chat for good (#687). A broken Agent preset shows the actual reason it failed to load (#75).
- Runtime environment: a reset first makes sure the related processes have exited, and an upgrade interrupted halfway keeps the user files it was carrying over. When safe mode moves dangerous files away and only part of it succeeds, it says so and you can retry the rest.
- Files and sharing: very long file names are shortened by bytes without splitting emoji, and keep their extension.
- Plugin development: a plugin that leaves out the capabilities parameter gets the v1 default instead of an empty list (#656).

## 1.0.12 · 2026-11-07

### 中文

- **更新前请注意：这一版的运行时有更新，所以还是下整包。** 内置引擎仍是 DSH 0.2.2-rc.1，变的是我们给它打的补丁。升级后 Linux 环境里只保留 `/root`，用 `apt` 装的软件和放在 `/usr/local`、`/opt` 等目录的文件需要重新装。对话和设置不受影响。
- **这一版没有在真机上验证过。** 目前在 x86_64 模拟器上用测试模型走过从 1.0.11 升级：运行时完成替换，对话和定时任务都在，`/root` 保留、`/usr/local` 清掉，升级后发消息正常。伙伴小屋只经过自动测试，没在模拟器上打开过。 遇到问题请开 issue 反馈。
- 伙伴小屋（新）：从「切换主机」面板进入的 Live2D 伙伴页面，可以摸摸她、和她聊天。轻量模式由手机直接调模型，不用启动引擎；完整模式在当前主机上开一个普通会话，能用主机的工具，审批照常。她会记得你写下的事；可以用手机自带的朗读或你自己配置的语音服务说话，也能用你自己的录音克隆音色，录音只发给你选的那个服务。Live2D 运行库和角色模型不随 App 提供，需要自己导入素材包。
- 悬浮宠物：长按打开半轮盘，新增「截图」，截下当前屏幕带进新对话的草稿，不会自动发送。需要 Android 11 及以上。
- 图片：点图片全屏查看，双指缩放、双击放大；同一组图片可以左右滑动切换。
- 英文界面：审批理由、插件市场分类和插件详情不再显示中文；英文的思考内容不再出现多余的翻译按钮。
- 对话：同一轮里的多段正式回答都会保留，不再被误折叠；上下文用量的估算说明更清楚。
- 远程：没选工作区时，新对话落到最近用过的工作区，新对话页会显示它；主机上一个工作区都没有时会写明「主机默认目录」。新增 `设置 › 远程主机 › 精简历史`，支持的 DSH Remote 主机可以只传历史工具输出的摘要。SSH 认证途中断线会继续重连，不再当成密钥错误，启动失败时显示详情。连接详情里能看到实际走的路径和 IPv4 / IPv6。
- 引擎：一个被改名或损坏的会话目录不再让整个引擎起不来，其余对话照常显示；安全模式在数据坏掉时用独立的数据目录启动，原来的对话保持原样。用 OpenAI 兼容协议接 Gemini 不再被 400 拒绝。插件安装、更新和热更新时的并发问题已修复；大量文本截断不再切坏字符，编辑文件时保留原来的 BOM 和行尾。
- 手机操控：OPPO、realme 等机型上确认卡的按钮点不动、只能等倒计时结束的问题已修复（#608、#632）。确认卡不再按触摸事件的字段猜是不是真手指，改成只拒绝 App 自己发出的点击，助手仍然不能替你点「允许」。这一项没在这些机型的真机上验证过。另外，无障碍服务被系统打断时不再直接停止本次操作；后台屏刚打开时的黑帧不再被报成安全窗口；无障碍授权自动恢复失败时会说明原因；通知上的两个停止按钮改叫「停止手机操控」和「停止引擎」。
- 设置：重置运行环境的确认框写明，`/root` 里没保留的内容（包括工作区文件、`AGENTS.md` 和插件自己存的数据）也会一起删除。
- 网页版：原版布局下侧栏按钮不再被 App 的浮钮挡住；顶栏按钮不再独占一排。

### English

- **Before you update: this version changes the runtime, so it's a full download again.** The built-in engine is still DSH 0.2.2-rc.1; what changed are the patches we apply to it. Only `/root` stays in the Linux environment, so software installed with `apt` and files in `/usr/local`, `/opt` and similar places need installing again. Chats and settings are kept.
- **This version hasn't been verified on a real phone.** So far it has run on an x86_64 emulator with a test model, updating from 1.0.11: the runtime was replaced, chats and scheduled tasks were kept, `/root` stayed and `/usr/local` was cleared, and messages worked after the update. The companion room has only been through automated tests and wasn't opened on the emulator. If you hit a problem, please open an issue.
- Companion room (new): a Live2D companion page, opened from the host switcher. You can pat her and talk to her. Light mode calls the model straight from the phone with no engine to start; full mode opens an ordinary conversation on the current host, with its tools and its usual approvals. She remembers what you write down for her, can speak with the phone's own text-to-speech or a speech service you configure, and can clone a voice from your own recording, which is sent only to the service you choose. The Live2D runtime and character models don't ship with the app; you import a pack yourself.
- Floating pet: a long press opens a half wheel with a new Screenshot item that takes the current screen into a new chat's draft, without sending it. Requires Android 11 or later.
- Images: tap an image to view it full screen, pinch or double-tap to zoom, and swipe between images of the same group.
- English interface: approval reasons, plugin market categories and plugin details no longer show Chinese, and English reasoning no longer shows a needless Translate button.
- Chat: every final answer in a turn is kept instead of being folded away by mistake, and the context usage estimate is explained more clearly.
- Remote: with no workspace selected, a new chat starts in the workspace you used last and the new chat page shows it; a host with no workspace at all says "Host default folder". New `Settings › Remote host › Compact history` lets supporting DSH Remote hosts send only summaries of past tool output. An SSH connection dropped during authentication keeps reconnecting instead of being reported as a key error, and a failed start shows its details. Connection details show the path actually used and IPv4 or IPv6.
- Engine: one renamed or damaged session folder no longer stops the whole engine from starting, and the other chats still show; safe mode starts on a separate data folder when the data is damaged, leaving the original chats untouched. Gemini through the OpenAI-compatible protocol is no longer rejected with a 400. Concurrency problems when installing, updating and hot-reloading plugins are fixed; many text truncations no longer cut characters apart, and editing a file keeps its BOM and line endings.
- Phone control: on OPPO, realme and similar phones the confirmation card's buttons no longer ignore taps until the countdown runs out (#608, #632). The card no longer guesses from touch event fields whether a finger is real; it only refuses taps the app itself sends, so the assistant still can't tap Allow for you. This hasn't been verified on those phones. Also, an accessibility service interrupted by the system no longer stops the current action; the black first frame of a just-opened background screen is no longer reported as a secure window; when restoring accessibility access automatically fails, the reason is shown; the notification's two stop buttons are now "Stop phone control" and "Stop engine".
- Settings: the reset runtime dialog says that anything in `/root` you don't keep, including workspace files, `AGENTS.md` and data plugins store themselves, is deleted too.
- Web UI: in the original layout the sidebar button is no longer covered by the app's floating button, and the header buttons no longer take a row of their own.

## 1.0.11 · 2026-11-05

### 中文

- **更新前请注意：这一版换了运行时，内置引擎升到 DSH 0.2.2-rc.1。** 升级后 Linux 环境里只保留 `/root`，用 `apt` 装的软件和放在 `/usr/local`、`/opt` 等目录的文件会被清掉，需要重新装。对话和设置不受影响。也因为换了运行时，这次还是下整包。新引擎写入后，定时任务不保证还能被旧版引擎读回，不建议退回旧版。
- **这一版的引擎升级还没在真机上验证过。** 目前在 x86_64 模拟器上用测试模型走过从 1.0.10 升级、发消息、定时任务、窄屏网页版和手机工具，没用过真实模型账号。遇到问题请开 issue 反馈。
- 网页版：手机宽度下改用官方的抽屉和设置页，顶部的菜单按钮打开官方抽屉。平板和横屏沿用原来的布局。
- 定时任务：**这里改了 1.0.10 的规则。** 官方页面新增的手动新建现在能用：你自己在页面或 App 里新建、修改任务不再二次确认，和官方一致。助手用工具新建、修改任务仍然要单独确认，拒绝或两分钟内没确认都不保存。确认卡防不住能读到凭据文件的程序，不能代替系统隔离。
- 定时任务：助手现在创建的任务用新的规则格式，列表里显示「自定义」，和官方一致。这类任务在 App 里能改名字和指令，时间不在这里改，请在对话里让助手改。
- 对话：手机顶栏把位置留给标题，第二行只放状态和工作区；输入框点进去展开成两行，换模型的按钮就在里面。左滑面板在开着对话时显示这段对话的信息和插件。
- 动效：新增「灵动动效」，有按压回弹、卡片展开成页面，文字匀速吐出并淡入。默认开启，省电模式和系统关闭动画时不生效，可在 `设置 › 性能` 里关掉。
- 插件：新增五个可放置的位置：`+` 面板的工具、侧栏的操作、回合脚注、插件页面板和弹窗面板。
- 手机操控：后台截图处理好了带行填充的画面，操作结束后浮层和触摸都会恢复，已结束的调用不再占着队列。
- 更新：取消下载后不再改写已有分片；响应头或错误内容很慢时不再一直占着连接；升级后的清理不再删掉刚校验好的新安装包。
- 分享和文件：损坏的分享链接会被拒绝；截断文字时不再切开表情；保存文件时先占住文件名，互不覆盖。
- 远程：请求超时后不再启动迟到的请求，也不再留下迟到的连接；重连不会取消已经选定的系统听写。
- 语音：录音读取失败时结束这次录音，不再留下半截文件；迟到的取消回执不再影响新一轮。
- 引擎：大量后台路径减少了重复计算和内存分配，比如长输出截断、文件搜索和会话列表。
- 限制：官方远程插件 0.6.2 还不支持新版的修改和立即运行，通过它连 0.2.2 主机时不能修改、删除或立即运行定时任务，可以查看。如果你在配置里完整复制过旧版的预设，新引擎可能启动不了这个预设，做法见 `docs/maintenance/dsh022-saved-preset-migration.md`。

### English

- **Before you update: this version changes the runtime, and the built-in engine is now DSH 0.2.2-rc.1.** Only `/root` stays in the Linux environment. Software installed with `apt` and files in `/usr/local`, `/opt` and similar places are removed and need installing again. Chats and settings aren't affected. Because the runtime changes, this is a full download. Once the new engine has written them, scheduled tasks may not read back on an older engine, so going back isn't recommended.
- **The engine upgrade hasn't been verified on a real phone yet.** So far it has run on an x86_64 emulator with a test model: updating from 1.0.10, messages, scheduled tasks, the narrow web UI and phone tools. No real model account was used. If you hit a problem, please open an issue.
- Web UI: at phone width it now uses the official drawer and settings sheet, and the menu button at the top opens the official drawer. Tablets and landscape keep the previous layout.
- Scheduled tasks: **this changes the rule from 1.0.10.** The official page's new manual create now works: when you create or edit a task yourself on the page or in the app, there's no second confirmation, as upstream has it. When the assistant creates or edits one through its tools, it still needs separate confirmation, and rejecting or not confirming within two minutes saves nothing. The card can't stop a program that can read the credentials file, so it doesn't replace system isolation.
- Scheduled tasks: tasks the assistant creates now use a new rule format and read "Custom" in the list, as on the official page. You can change their name and instruction in the app. To change the time, ask the assistant in a chat.
- Chat: the phone header gives its room to the title, with only status and workspace on the second line. The composer opens into two rows when you tap it, with the model button inside. With a chat open, the swipe panel shows that chat's info and plugins.
- Motion: a new "Fluid motion" setting adds press rebound, cards that expand into pages, and text that streams at an even pace and fades in. It's on by default, has no effect in battery saver or when the system turns animations off, and can be turned off in `Settings › Performance`.
- Plugins: five more places to put things: tools on the `+` panel, actions in the side panel, turn notes, panels on a plugin's own page, and panels that open as a sheet.
- Phone control: background screenshots handle frames with row padding, the overlay and touch come back after an action, and finished calls no longer hold up the queue.
- Updates: cancelling a download no longer rewrites existing chunks, a slow response header or error body no longer holds a connection, and cleanup after an update no longer deletes a freshly verified package.
- Sharing and files: damaged share links are refused, truncating text no longer cuts an emoji in half, and saving a file claims its name first so saves don't overwrite each other.
- Remote: a request that timed out no longer starts late or leaves a late connection, and reconnecting no longer cancels a system dictation you already chose.
- Voice: a failed recording read ends that recording instead of leaving a partial file, and a late cancel no longer affects the next round.
- Engine: many background paths do less repeated work and allocate less, such as long output truncation, file search and the session list.
- Limits: the official remote plugin 0.6.2 doesn't support the new edit and run yet, so through it on a 0.2.2 host you can view scheduled tasks but not edit, delete or run them. If you copied a whole old preset into your config, the new engine may fail to start it; see `docs/maintenance/dsh022-saved-preset-migration.md`.

## 1.0.10 · 2026-11-04

### 中文

- **更新前请注意：这一版换了运行时。** 升级后 Linux 环境里只保留 `/root`，用 `apt` 装的软件和放在 `/usr/local`、`/opt` 等目录的文件会被清掉，需要重新装。对话和设置不受影响。也因为换了运行时，这次还是下整包。
- 定时任务：新建任务、修改任务的名称、指令或时间，都要单独确认。确认卡会展示完整指令、规则、时区和实际触发时间；完全权限、自动审查和「本对话都允许」都不能代替这次确认。拒绝、两分钟内没确认或没有可用的确认界面时，这次改动不会保存。限制：更新前已经存在的任务不会补做授权，请检查并删除不认识的任务；远程主机要装同样的引擎修复才有这道检查；授权不能代替凭据和工具执行的系统隔离。这项还没在真机上验证过，遇到问题请开 issue 反馈。
- 动效：弹窗和返回手势跟手，松手后顺着手指的速度由弹簧收住；拉过头有阻尼，回弹途中再抓住会从当前位置接着拖。
- 动效：按压改用弹簧；滚动列表时不再闪一下按下的效果，快速点按也看得见。
- 动效：等待的三个点换成思考或正文时不再硬切；思考文字上有一道缓慢的亮度扫光，图标转得更慢；工具之后直接出正文时，回复不再跳一下；输入框多一行时平滑长高。
- 动画开关现在也管页面切换、底部弹窗和壁纸、启动画面的预览。系统的「移除动画」同样生效，App 开着时改也立刻生效。弹窗移动时不做模糊，只在停稳后模糊，中低端手机上更省。这些手感还没在真机上验证过，遇到问题请开 issue 反馈。
- 安装包小了约 13 MB：arm64 包不再带另外两种架构用不上的库。
- 远程：聊天输入框可以把文件上传到当前会话的工作目录，不再只能传图片。单个文件最大 200 MiB；走 Relay/TURN、未知路径或旧版主机时通常仍限 20 MiB，以主机的回复为准。这项还没在真实远程主机上验证过，遇到问题请开 issue 反馈。
- 远程：抽屉底部的主机图标直接打开连接详情，点主机名或下拉仍是切换主机；本机图标打开引擎页。
- 模型：`设置 › 模型` 顶部新增**新对话默认**，可以沿用上次的选择，也可以固定一个模型和思考深度。固定默认需要新版引擎支持。
- 对话：回复里由引擎提供的图片（比如表情包插件的图）现在能显示，不再一律显示“无法显示”。展开的待办清单超长时，滑到底不再被拉回，能看到最后几项。
- 对话：手动 `/compact` 不再在 120 秒时被中断，等待上限改为 30 分钟；模型、远程主机或代理自己的限制仍然有效。
- 不打扰模式：能力自检改用测试窗口实际收到的触摸来判断，并等新建的后台屏准备好，部分 Android 17 设备不再一直显示未就绪；后台屏被任务占用时提示任务结束后重试，失败提示会带上出错的步骤。这些还没在 Android 17 真机上验证过。
- 手机操控：拿不到有效画面时，不再把空白界面当成“界面没变”或“已经到底”，也不再把手势发出去就当成操作成功；读屏连接超时后也会关闭。
- 引擎：PRoot 启动早期的权限错误和符号链接循环会归为启动失败；启动前清理已确认无主的 PRoot 临时目录，清理失败不影响启动。
- 远程连接：每次新建连接都会重新尝试获取 TURN 凭据。
- 语音：下载模型时写入失败（比如磁盘满）会正常报错，不再卡住。
- 关于：展示原作者和 B 站、X、GitHub 主页的链接。

### English

- **Before you update: this version changes the runtime.** Only `/root` stays in the Linux environment. Software installed with `apt` and files in `/usr/local`, `/opt` and similar places are removed and need installing again. Chats and settings aren't affected. Because the runtime changed, this update is still a full download.
- Scheduled tasks: creating a task, or changing its name, instructions or time, now needs its own confirmation. The card shows the full instructions, rule, time zone and actual trigger time, and full access, auto review and **Allow for chat** can't stand in for it. If you reject it, don't confirm within two minutes, or no confirmation screen is available, the change isn't saved. Limits: tasks that existed before this update aren't reviewed retroactively, so please check them and delete any you don't recognize; a remote host needs the same engine fix to have this check; and the confirmation doesn't replace system isolation of credentials and tool execution. This hasn't been tried on a real device yet, so please open an issue if it misbehaves.
- Motion: sheets and the back gesture follow your finger, and on release a spring carries on at the finger's speed. Pulling too far meets resistance, and catching a sheet on its way back carries on from where it is.
- Motion: presses settle on a spring. Scrolling a list no longer flashes a press, and quick taps still show one.
- Motion: the waiting dots no longer cut to thinking or text. The thinking label has a slow brightness sweep and its icon turns more slowly. A reply no longer jumps when text comes straight after a tool, and the composer grows smoothly by a line.
- The animation switch now also covers page transitions, bottom sheets, and the wallpaper and launch previews. The system's remove-animations setting does too, including when changed with the app open. Sheets blur only at rest, not while moving, which is cheaper on mid-range and low-end phones. None of this has been felt on a real device yet, so please open an issue if it misbehaves.
- The APK is about 13 MB smaller: the arm64 package no longer carries libraries for the other two architectures.
- Remote: the composer can upload files to the current chat's working directory, not only images. Each file can be up to 200 MiB; over Relay or TURN, on an unknown path or with an older host the limit is usually still 20 MiB, and the host's reply decides. This hasn't been tried on a real remote host yet, so please open an issue if it misbehaves.
- Remote: the host icon at the bottom of the drawer opens the connection details directly, and the host name or dropdown still switches hosts. The local icon opens the engine page.
- Models: `Settings › Models` has **New chat defaults** at the top. Keep your last choice, or fix a model and thinking effort. A fixed default needs an engine that supports it.
- Chat: images the engine serves itself in replies, such as those from an emoji plugin, now load instead of showing "can't display". A long expanded to-do list no longer pulls back when you scroll to the end, so the last items can be seen.
- Chat: a manual `/compact` is no longer cut off at 120 seconds. It can now wait up to 30 minutes, though limits set by the model, a remote host or a proxy still apply.
- Do Not Disturb: the capability check now goes by the touches a test window really receives and waits for a new background screen to be ready, so some Android 17 devices no longer stay on Not ready. While a task holds the background screen, it says to retry when the task ends, and failures name the step that failed. None of this has been tried on an Android 17 device.
- Phone control: without a usable view of the screen, a blank capture no longer reads as "nothing changed" or "reached the end", and a sent gesture no longer counts as a success by itself. A screen-reading connection that times out is now closed too.
- Engine: permission and symlink-loop errors early in PRoot startup are classified as launch failures. Before a launch, PRoot temp directories confirmed abandoned are cleaned up, and a failed cleanup doesn't block the launch.
- Remote: each new connection tries again for TURN credentials.
- Voice: a failed write during a model download, such as a full disk, now reports an error instead of hanging.
- About: shows the original author, with links to their Bilibili, X and GitHub profiles.

## 1.0.9 · 2026-11-02

### 中文

- Android 17：不打扰模式能点了。系统删掉了后台屏下发输入要用的隐藏接口，root、Sui、Shizuku、自连 ADB 四条通道都只能读屏、点不了，现在改用还在的接口。我们手上没有 Android 17 真机，遇到问题请开 issue 反馈。
- Android 17：自连 ADB 用的 TLS 库（Conscrypt）升到 2.8.0，在 16 KB 内存页的设备上也能加载。
- 不打扰模式：新增「保持 X 通道」开关，默认关。打开后，通道断开、App 被杀或手机重启，都会自己连回去。root 打开后 DSH Go 会自己再向 root 管理器申请，给不给仍由管理器决定；没打开就绝不会自动执行 `su`。这个开关还没在真机上验证过，遇到问题请开 issue 反馈。
- 不打扰模式：读后台屏时按包名取目标 App 的窗口，不再只看第一个窗口；每次点按、滑动、按键只发一次，系统没确认时不再说「系统拒绝」，也不再让你去开 USB 调试；对后台屏按 HOME 这类系统键会直接失败，不再把物理屏送回桌面；root 的一键授权复用已连接的 root，不再多跑一次 `su`。
- 自连 ADB：在通知里输入配对码现在真的能配对了（以前每次都失败，结果还被丢掉，看起来没有任何反应），通知会显示配对结果。
- 手机操控悬浮条：胶囊 3 秒不碰就按「闲置时不透明度」变淡，碰一下恢复；卡片和等你处理的时候不变淡。开了「闲置时自动收起」的，还是先收成小球再变淡。
- 新增左滑快捷入口：在聊天区左滑，从右侧打开插件、引擎、设置等常用入口。可以在 设置 → 界面 里关掉，或者选显示哪些、调顺序。
- 会话：永久删除不再误报「此主机不支持」，引擎还没准备好时提示暂不可用；刚新建、还没写到磁盘的会话也能删了；删除一次只发一个请求。会话搜索跟随当前连接，不再用旧连接的结果回答。
- 对话：准备失败或中断时，还没被接收的输入按原顺序放回队列，不会丢。图片被拒时，不再一律让你换 V4.1 Flash，而是说明当前模型没声明支持图片，可以换模型或把自定义模型的输入类型改成「文本和图片」。
- 附件：单个文件上限从 30 MB 提到 200 MB，单条消息总量 400 MB；文件走引擎的流式上传。旧版主机上仍是 30 MB。
- 网络：引擎把 IPv4 和 IPv6 分开解析，网络拒绝 IPv6 查询时不再连带 IPv4 一起失败。PRoot 里的 git、curl、pip 这次没有覆盖到。
- 引擎：卡死时，停止和重置会等旧进程真正退出；启动早期堆内存耗尽会计入自动安全模式，不再每次打开都加载同一个插件。
- 更新：优先从 dl.dshtui.com 下载，并支持增量更新（这一版换了运行时，还是下整包，下一版起才会变小）；点了安装后没等到系统结果时，不再说「已取消安装」，安装包会留着。
- 插件市场：优先从 dl.dshtui.com 读目录，手机上留一份，读不到时用这份。
- 分享：导出和分享对话时，`Authorization` 请求头里的凭据会被隐藏。
- 文件：XLSX 预览的预算把铺开的空单元格也算进去；刷新之后不再被更早的修改时间覆盖。
- 终端：改名失败的结果晚到时，不再影响已离开的页面或重建后的终端。
- 插件：重载之后才完成的面板视图不再用旧注册回答；App 在后台时新建的流也会按时关闭；被关闭的连接中止的文件回调不再算成插件的错。
- 手机操控工具：`run_code` 能看到 intent、collect、tap_xy 的参数了；tap_xy 缺屏幕号时报错说对参数名。
- 诊断：快照里的内存和剩余存储单位对了，不再把 GiB 显示成 MB。
- 插件开发：插件技能和检查清单按 view v2 写，不再说只有 16 个组件。
- 性能：解压运行时并行解码；引擎日志成批处理；长对话只折叠新增的部分；重复打开会话列表跳过没变的记录；启动缓存在 Direct 模式下也生效；本机连接不等 mux 就能先加载会话列表。

### English

- Android 17: Do Not Disturb can tap again. The system removed the hidden interface the background screen used to send input, so root, Sui, Shizuku and self-paired ADB could all read the screen but not touch it; it now uses the one that remains. We don't have an Android 17 device, so please open an issue if it misbehaves.
- Android 17: the TLS library self-paired ADB uses (Conscrypt) is now 2.8.0, which loads on 16 KB-page devices.
- Do Not Disturb: a new "Keep this channel" switch, off by default. With it on, the channel reconnects by itself after a drop, the app being killed or a reboot. For root, DSH Go asks your root manager again by itself and the manager still decides; with it off, `su` never runs on its own. This switch hasn't been tried on a real device yet, so please open an issue if it misbehaves.
- Do Not Disturb: reading the background screen picks the target app's window by package instead of only looking at the first; each tap, swipe and key is sent once, and when the system doesn't confirm one it no longer says "rejected" or sends you to USB debugging settings; HOME and similar system keys on the background screen fail outright instead of sending the physical screen home; the one-tap root grant reuses the connected root instead of running `su` again.
- Self-paired ADB: typing the pairing code into the notification now really pairs (it used to fail every time and drop the result, so nothing seemed to happen), and the notification shows the outcome.
- Phone control overlay: the capsule fades to Idle opacity after 3 seconds untouched and comes back at a touch; the card and anything waiting for you stay solid. With Collapse when idle on, it still shrinks to a ball first and the ball fades.
- New left-swipe shortcuts: swipe left over the chat to open plugins, engine, settings and other common places from the right. Turn it off or choose and order the items in Settings → Interface.
- Sessions: permanent delete no longer says "this host doesn't support it" while the engine is starting; a new session that was never written to disk can be deleted; one delete sends one request. Session search follows the current connection instead of answering from the old one.
- Chat: input not yet accepted goes back to the queue in order when preparing fails or a turn is interrupted, so it isn't lost. Image refusals no longer send everyone to V4.1 Flash: they say the model doesn't declare image input, and that you can switch models or set a custom model's Input to Text + image.
- Attachments: up to 200 MB per file (was 30 MB) and 400 MB per message, uploaded through the engine's streaming route. Older hosts stay at 30 MB.
- Network: the engine resolves IPv4 and IPv6 separately, so a network that refuses IPv6 lookups no longer takes IPv4 down too. git, curl and pip inside PRoot aren't covered yet.
- Engine: when it hangs, stop and reset wait for the old process to really exit; running out of heap early in startup now counts toward safe mode, so the same plugin isn't loaded on every launch.
- Updates: downloads come from dl.dshtui.com first, with delta updates (this version changes the runtime, so it's still a full download; they get smaller from the next one); an install with no result from the system no longer says "cancelled", and the package is kept.
- Plugin market: the catalog comes from dl.dshtui.com first, with a copy kept on the phone for when it can't be read.
- Sharing: credentials in `Authorization` headers are hidden in exports and shares.
- Files: the XLSX preview's budget counts the empty cells it lays out; an older modified time can't overwrite a newer one after a refresh.
- Terminal: a late rename failure can't touch a page you left or a rebuilt terminal.
- Plugins: a panel view that finishes after a reload no longer answers from the old registration; a stream made while the app is in the background still closes on time; a file callback stopped by a closed connection isn't counted against the plugin.
- Phone control tools: `run_code` now sees the parameters of intent, collect and tap_xy; tap_xy's missing-screen error names the right parameter.
- Diagnostics: memory and free storage in the snapshot have the right units, no longer showing GiB as MB.
- Plugin development: the plugin skill and checklist describe view v2, not only 16 components.
- Performance: the runtime unpacks with parallel decoding; engine logs are batched; long chats fold only what's new; re-opening the session list skips unchanged records; the boot cache also works in Direct mode; the local connection can load the session list before the mux is up.

## 1.0.8 · 2026-11-01

### 中文

- 不打扰模式：「Shizuku 可用」改为看接口本身，不再要求装 Shizuku App——只装了 Sui（Magisk / KernelSU 模块）的设备也能直接用，状态里写明接口来自 Sui 还是 Shizuku；两者都没有、和有 Sui 但还没授权，提示分开说。
- 不打扰模式：新增 root 通道，给已 root（Magisk / KernelSU / APatch）但没有 Shizuku 的设备。只有你在页面上选了 root 才会第一次执行 `su`，授权走 root 管理器自己的弹窗；「自动恢复无障碍」的一键授予也能走 root。
- 不打扰模式：通道选择改成一个面板——关闭 / Shizuku / Sui / root / 自连 ADB，各自写明适合谁、现在什么状态，并标出推荐的那个（只推荐，不替你选）；失败时显示真实原因，不会悄悄换到别的通道。Sui 和 root 两条通道还没在真机上验证过，遇到问题请开 issue 反馈。
- 自连 ADB：修了「连接 → 启用」的检查死循环，端口可以手动填；切换通道时只断开要离开的那条，已经连好的 ADB 不再被一并断掉；一次操作被超时或停止打断后，不再复用旧连接，避免下一步收到上一步迟到的结果。
- 会话：可以永久删除对话（长按单删、多选批量删）；可以浏览并恢复已归档的对话；可以直接在某个文件夹里新建对话。
- 悬浮宠物：App 外的宠物和 App 内一样大；思考、子代理等动画完整显示，不再被裁掉；App 在后台时一轮结束，宠物气泡和通知照常出现；App 在后台时暂停宠物动画计时。
- 实时活动：运行状态显示在状态栏、锁屏和厂商灵动岛（如小米焦点通知），配宠物头像。
- 输入框上方：自动允许、插件胶囊不再各占一行；目标、待办、插件和状态条可以叠成一行卡片，点开有展开动画，叠着时左右滑动换到最前面。可以在 ui.json 里隐藏内置的插件胶囊。
- 手机操控悬浮条：重做成圆球、胶囊、圆角卡片三级，最常用的操作信息放在最前，暂停 / 停止重新排布，次要信息收进下一层。
- 插件设置：插件声明的字段都能显示，有中文标题优先用中文；十个常用插件补了中文字段说明；改一个字段只刷新那一行，不再卡；跳到网页版设置不再和它抢着改、也不会卡住。
- 图像与视频：设置页按服务商整理，同一服务商的几项服务共用一把 key，预设自动填好地址和模型。
- 对话：外接键盘可选 Enter 发送；在光标处输入 `/` 也能补全命令，不丢草稿；表格底色三档可选（带预览），表格紧贴段落也能正常显示；模型卡长名字完整显示，token 统一用 K / M；订阅渠道的上下文长度可以自己设。
- 外观：原生界面跟随主机设定的深浅色。
- 网页版：App 内的网页版可以上传文件。
- 渠道：思考级别留空不再让渠道失效。
- 性能：流式输出时复用已有的行和索引、复用已完成段落的扫描结果；侧边栏按需构造会话条目；顶栏状态文字不再重复测量。
- 源码：1.0.5–1.0.7 的源码已补进公开仓库，保留逐个提交的历史，对应的 tag 也改指到了正确的提交。

### English

- Do Not Disturb: Shizuku is now judged by its interface, not by the Shizuku app — devices with only Sui (a Magisk / KernelSU module) work as is, and the status says whether the interface comes from Sui or Shizuku. "Neither installed" and "Sui present but not authorized" are told apart.
- Do Not Disturb: a new root channel for rooted devices (Magisk / KernelSU / APatch) without Shizuku. `su` runs for the first time only after you pick root on the page, and the prompt is your root manager's own. The one-tap grant for auto-restoring accessibility can use root too.
- Do Not Disturb: picking a channel is one panel — off / Shizuku / Sui / root / self-paired ADB, each with who it's for and its current state, the recommended one marked (marked, never picked for you). Failures show the real reason and never switch channels behind your back. The Sui and root channels have not been tried on real devices yet — please open an issue if something goes wrong.
- Self-paired ADB: the connect → enable check no longer loops and the port can be entered by hand; switching channels closes only the one being left, so a connected ADB stays connected; after a step is interrupted by a timeout or Stop, the old connection is retired instead of reused, so the next step can't receive the previous one's late reply.
- Sessions: delete conversations for good (long-press one, or select several); browse and restore archived conversations; start a new conversation inside a folder.
- Floating pet: the pet outside the app is the same size as inside; thinking, subagent and other animations are drawn whole instead of clipped; a turn that ends while the app is in the background still reaches the pet's bubble and the notification; the pet's animation timer pauses while the app is in the background.
- Live activity: run status in the status bar, on the lock screen and in vendor islands (e.g. Xiaomi focus notifications), with the pet's portrait.
- Above the composer: auto-approve and plugin chips no longer take a row each; goal, todos, plugins and the status strip can stack into one row of cards that expands with an animation, and swiping a folded stack brings another card to the front. The built-in Plugins chip can be hidden from ui.json.
- Phone control overlay: redesigned as ball, capsule and rounded card on one surface — the operation info that matters up front, pause / stop re-laid, the rest one level down.
- Plugin settings: every declared field shows up, Chinese titles first; ten popular plugins get Chinese field copy; editing a field redraws only its row, so no more lag; handing over to the web settings no longer races them or freezes.
- Images & video: the settings page is organized by provider; a provider's services share one key, and presets fill in the address and models.
- Chat: optional Enter-to-send for hardware keyboards; `/` at the cursor completes commands without losing the draft; three table tint levels (with preview), and tables written flush against a paragraph still render; long model names show in full, token counts use K / M; the context length of subscription providers is configurable.
- Appearance: the native app follows the host's light / dark setting.
- Web: file uploads work in the in-app web view.
- Providers: an empty thinking level no longer breaks a provider.
- Performance: streaming reuses existing rows, indices and the scan of finished lines; the drawer builds session rows on demand; the top bar's status text is measured once.
- Source: the 1.0.5–1.0.7 source is now in the public repository with its commit-by-commit history, and those tags point at the right commits.

## 1.0.7 · 2026-10-31

### 中文

- 排障：引擎起来后，App 会把一份脱敏的本机诊断写进引擎（`$DSH_HOME/dsh-app/diagnostics.md`）：版本、设备、运行时、启动方式、连接、性能档位、最近错误和日志尾部。新增内置技能 `dsh-go-support`，教 AI 先读它再排查，并按症状给出可直接粘贴的 issue 草稿。
- 设置 → 诊断新增「让 AI 看诊断」：手动刷新这份快照，然后问 AI「看下诊断」就行。
- 更新：修了「已经是 1.0.4 却提示最新」——某个更新源停在旧版本时，不再就此收工，会继续问其它源，取更新的那个；公测包也不再带内测通道令牌，免得一个过期的内测清单盖住 GitHub 的新版本。

### English

- Support: once the engine is up, the app writes a redacted local diagnostics snapshot into it (`$DSH_HOME/dsh-app/diagnostics.md`): versions, device, runtime, launch mode, connection, performance tier, recent errors and log tails. The new bundled `dsh-go-support` skill tells the agent to read it first, walk the symptom, and draft an issue you can paste.
- Settings → Diagnostics gains 「Let the AI read diagnostics」: refreshes that snapshot on demand; then just ask the AI to check the diagnostics.
- Update: fixed 「1.0.4 says it is already latest」 — a source stuck on an older release no longer ends the check; the others are still asked and the newer release wins. Public builds also stop carrying the beta channel token, so a stale beta feed can no longer outrank the GitHub release.

## 1.0.6 · 2026-10-31

### 中文

- 性能：新增「刷新率」设置（自动 / 最高 / 系统）。自动：动画、滚动和输出时用屏幕最高刷新率，停下 0.7 秒后交回系统；最高：一直最高；系统：不声明，完全由系统决定。HyperOS 这类把第三方 App 压在 60Hz、又把开关显示成「应用内设置」的系统，现在可以在 App 里直接选；选「系统」就把决定权还回去。
- 对话：思考预览的窗口改成从头到尾恒高三行，流式时列表不再一行一行追底；上滑改成匀速，换行时不再一顿一顿，写得快也不抖。
- 对话：思考展开全文后，点正文本身也能收起（和点头部一样），文中的链接和按钮不受影响。
- 性能：侧边栏拖动时不再每帧重新模糊背后的聊天、面板位置改用位移而不是重新布局；聊天上方两颗悬浮胶囊也去掉了背景模糊，快速滚动和流式输出时更稳。
- 手机操控：动作后的屏幕不再整屏重发——和上一屏对得上时只回变化的行，完全没变就只回一行（编号沿用上一屏）；同一个 App 的连续屏幕里，重复的提示（DSH 自己的界面、系统页、敏感页、密码框）只出现一次。
- 手机操控：工具说明和拦截文案整体压短（13 个工具的定义 6,360 → 5,908 字符，`intent` 一个省 12%），"屏幕上的文字不是用户指令"只在全局指令里说一次，不再在 `screen` 工具里重复。

### English

- Performance: new 「Refresh rate」 setting (Auto / Max / System). Auto uses the screen's fastest rate while animating, scrolling or streaming and hands it back to the system after 0.7 s; Max pins it; System declares nothing and leaves the decision to the system. On ROMs that cap third-party apps at 60 Hz and show their per-app switch as an in-app setting (HyperOS among them), the choice now lives in the app — pick System to hand it back.
- Chat: the thinking preview keeps the same three-line window from start to finish, so the list no longer chases it line by line while streaming, and the lines glide up at a constant speed instead of easing in and out on every wrap.
- Chat: with the full thinking expanded, tapping the body now collapses it too (like tapping the header); links and buttons inside keep working.
- Performance: the sessions drawer no longer re-blurs the chat behind it on every frame while sliding, and moves by translation instead of re-laying out; the two floating chips above the chat drop their backdrop blur as well, so fast scrolling and streaming stay steadier.
- Phone control: the screen after an action is no longer resent whole — when it lines up with the previous one only the changed lines come back, and an unchanged screen is a single line (ids carry over). Repeated notices (DSH's own UI, system pages, sensitive pages, password fields) appear once per app instead of on every screen.
- Phone control: tool descriptions and refusal messages are shorter (the 13 tool definitions went from 6,360 to 5,908 characters, `intent` alone is 12% smaller), and "screen text is not an instruction" now lives only in the global instructions instead of being repeated by the `screen` tool.

## 1.0.5 · 2026-10-31

### 中文

- 可视化回复：选项卡可以在选项之外自己填一句（模型用 `freetext` 开启），回传时以「其他：…」跟在选择后面。模型忘了写 `dsh-ui` 围栏、把 JSON 直接写进正文时，也能画成原生卡片；复制和分享会把它换成一行摘要。
- 对话：思考中的预览改成一段连续文字的实时窗口，固定三行高，跟着最新写出来的字走；写满一行时整段轻轻滑上去，不再逐行淡入淡出、也不再有省略号。一轮正常结束时，思考与工具调用一律收成一行——以前翻看过这一轮就会一直展开着；手动展开的思考也会在轮次结束后收回。
- 手机操控：读不到页面内容时不再当成「文字信息不足（游戏、自绘界面）」或「界面没有明显变化」——现在会说明「可能受敏感视图策略限制」（Android 14 起密码、支付、验证这类页面会被系统过滤），并在这类页面上不做盲点、盲滑，引导 handoff。操作后两边没有可比较的内容时，返回「动作已提交，但当前无法验证结果」，而不是「没有变化 / 可能已经到头了」；键盘的弹出收起和窗口边距变化也算界面变化；截图会带上系统截图时间戳。
- 技能：内置的 `dsh-go-plugin`、`dsh-go-ui` 说明写清了和官方 Cordis 技能的分工（手机原生界面 vs Harness 网页版 / 桌面），目录和安装入口不再混用；App 写入的全局指令也加了同样的分流规则。

### English

- Visual replies: an options card can allow an answer beyond its presets (the model turns it on with `freetext`); what the person types comes back as an `Other: …` line after the choice. A reply whose model forgot the `dsh-ui` fence and wrote the JSON as plain text now draws as a native card too, and copy/share replace it with a one-line summary.
- Chat: the thinking preview is a three-line live window of continuous text that follows the newest words and glides up a line when one fills; the per-line fading and the leading ellipsis are gone. A turn that ends normally always folds its thinking and tool calls into one row — previously a turn you had scrolled through stayed expanded; thinking you expanded by hand folds back when the turn ends.
- Phone control: a page whose content cannot be read is no longer reported as a poor tree ("game / custom-drawn UI") or as "no visible change" — it now says the content may be blocked by the sensitive-view policy (Android 14+ filters pages like passwords, payments and verification), stops blind taps and swipes there and points to handoff. When an action leaves nothing comparable on either side it reports "submitted, but the result cannot be verified" instead of "unchanged / probably at the end of the list"; IME show/hide and window inset changes count as screen changes, and a screenshot carries the system timestamp.
- Skills: the bundled `dsh-go-plugin` and `dsh-go-ui` instructions now spell out how they divide work with the official Cordis skills (phone-native UI vs Harness Web / desktop), so directories and install entries are no longer mixed; the app's global instructions follow the same routing rule.

## 1.0.4 · 2026-10-31

### 中文

- 正式下载统一为 arm64 安装包，发布页明确标出安装包和辅助更新文件的用途。
- DSH Remote 默认自动选择连接方式，优先尝试局域网 / P2P，再尝试 TURN，最后回落 Relay。升级后不再需要打开直连开关，旧的关闭设置也会迁移到自动策略；相应路径需服务端与主机支持。
- 新增网络详情：点击连接卡或主机旁的网络标签，查看实际路径、连接耗时、可测的往返延迟及回落原因。重连后清除旧测量，改善 Wi-Fi 与蜂窝网络切换时的连接恢复。
- 官方插件市场已上架「生图生视频」，支持在当前主机上生成图片和视频。可从「设置 → 插件 → 插件市场 → 官方」安装；主机尚未安装时，「设置 → 图像与视频」也有安装入口。插件需单独安装并配置服务商。

### English

- Public downloads now provide one arm64 installer, with release-page guidance distinguishing it from update and verification files.
- DSH Remote now selects its connection automatically, trying LAN / P2P first, then TURN, and finally Relay. Upgrading also migrates the old disabled-direct setting to the automatic policy. Compatible server and Host support is required for each path.
- Added network details. Tap the route label on the connection card or beside a Host to see the actual route, connection time, available round-trip latency and fallback reason. Old measurements are cleared after reconnects, with improved recovery when switching between Wi-Fi and cellular networks.
- The official plugin market now includes Images and video for generation on the selected Host. Install it from Settings → Plugins → Plugin market → Official, or from Settings → Images and video when it is missing. The plugin remains a separate install and requires provider configuration.

## 1.0.3 · 2026-10-31

### 中文

- 修复更换桌面图标后出现两个入口的问题：保留正在使用的页面，回到桌面后完成切换；连续更换、强停后重开和刚切换就重启也能恢复最后选择。
- 手机操控新增无障碍自动恢复设置。授予系统设置权限后，手机操控开启期间会尝试恢复被关闭或断开的服务，并保留其他无障碍服务。Android 强制停止 App 后仍需手动重新打开。
- 桌宠新增「问一句」和新会话入口，可直接在气泡里处理支持的工具审批与简单问题；语音识别结果先回填草稿，由你确认发送。修复无障碍浮窗异常时的窗口创建、频繁重试，以及键盘遮挡输入栏的问题。
- DSH Remote 新增可选 P2P 直连和 TURN 配置，默认关闭；直连不可用时回退中继。需服务端与主机支持相应协议。
- 插件市场支持官方目录、固定版本更新、风险说明和分享链接，媒体生成设置也可跳转到对应插件。插件仍需单独安装，未上架的插件不会显示为可安装。

### English

- Fixed duplicate launcher entries after changing the app icon. The current page stays open, and the switch finishes when you return home. Rapid changes, relaunches after force-stop, and reboots immediately after a change retain the saved choice.
- Added optional accessibility recovery for Phone Control. After granting secure-settings access, the app can restore a disabled or disconnected service while Phone Control is enabled, preserving other accessibility services. Android force-stop still requires reopening the app.
- Added quick asks and new chats from the floating pet, supported approval and simple-question actions in bubbles, and voice input that fills a draft for explicit sending. Fixed accessibility-overlay window creation, excessive retries after a window failure, and the keyboard covering the input bar.
- Added opt-in P2P and TURN configuration for DSH Remote, off by default, with Relay fallback when direct connection is unavailable. Compatible server and Host support is required.
- The plugin market now supports an official catalog, pinned-version updates, risk notices and share links. Media generation settings link to the relevant plugin. Plugins remain separate installs; unpublished packages are not offered as installable.

## 1.0.2 · 2026-10-30

### 中文

- DSH Remote 更省流量：会话列表不再在每次对话状态变化时整份重新下载；App 切到后台 30 秒后，进行中的对话暂停逐字推送，回到前台时一次同步到最新（会短暂显示同步中）；连接有数据往来时不再额外发送检测请求，网络慢时也不容易误判断线、反复重连。
- DSH Remote 跟进 ds-harness-remote 的最新协议：主机插件更新到 0.6.0 后，远程流量会改走服务器分配的独立中继节点，减轻主服务器的压力；协议校验也和上游保持一致。

### English

- DSH Remote uses less data: the session list is no longer downloaded in full every time a chat changes state; 30 seconds after DSH Go goes to the background, a running chat stops streaming word by word and catches up in one go when you return (it shows syncing briefly); and the connection no longer sends extra health checks while data is flowing, so a slow network is less likely to look like a drop and reconnect over and over.
- DSH Remote follows the latest ds-harness-remote protocol: once the Host plugin is on 0.6.0, remote traffic moves to a separate Relay node assigned by the server, taking load off the main server; protocol checks match upstream too.

## 1.0.1 · 2026-10-30

### 中文

- 高刷新率：在支持 90Hz、120Hz 的手机上，DSH Go 会用屏幕最高的刷新率运行。之前部分系统（例如 OriginOS、HyperOS、ColorOS）会把它限制在 60Hz 或 90Hz。系统设置里选的刷新率和省电模式仍然优先。
- 安装包同时带 v1、v2、v3 三种签名，只认旧式签名的安装器和安全检测也能正常安装。签名证书没有变，可以直接覆盖 1.0.0 升级，对话和设置都会保留。
- 应用内更新的弹窗里多了一个「去 Star」按钮，可以顺手去 GitHub 给项目点个 Star。
- GitHub 发布页只放常见手机用的 arm64 安装包；模拟器和 x86 设备用的版本在发布说明末尾的「其他版本下载」里。

### English

- High refresh rate: on 90 Hz and 120 Hz phones, DSH Go now runs at the screen's highest refresh rate. Some systems (OriginOS, HyperOS and ColorOS, for example) used to hold it at 60 or 90 Hz. The refresh rate you choose in system settings and power saving still come first.
- The APK now carries v1, v2 and v3 signatures, so installers and security checks that only read the older signature accept it too. The signing certificate hasn't changed: it installs over 1.0.0 and keeps your chats and settings.
- The in-app update sheet has a Star it button for a quick star on GitHub.
- The GitHub release page offers the arm64 APK for most phones; the build for emulators and x86 devices is under "Other builds" at the end of the release notes.

## 1.0.0 · 2026-10-30

### 中文

DSH Go 1.0.0 来了，这是第一个公开版本。它让你在 Android 手机上运行 DeepSeek Harness（DSH），也能连上电脑或服务器上的 DSH，走到哪儿都能接着聊、接着干活。DSH Go 以 AGPL-3.0 开源，欢迎来 GitHub 看看。感谢测试期间每一位反馈问题、提出建议的朋友；已经在用 0.9.10 的，这一版功能不变，只是正式换上 1.0.0 的版本号。

现在的 DSH Go 可以：

- **本机运行**：在 App 里装好 Ubuntu、Node.js 和 DSH 运行环境，不用 Root，也不用另装 Termux。
- **远程主机**：通过 SSH 或 DSH Remote 使用电脑、服务器上的 DSH；只连远程时，手机上不必安装运行环境。
- **对话**：切换模型、发图片，回复中途也能插话；工具审批和提问在对话里直接处理，原生界面和网页版一键切换。
- **插件**：从插件市场安装；适配 DSH Go 的插件以原生的工具卡、表单和面板呈现，设置页也是原生的。仓库附带 SDK、教程和示例。
- **手机操控**：开启权限后，让本机引擎看屏幕、点按和输入，随时可以暂停或停止。确认方式可选「关键步骤先问我」或「全程自动」；可选的「解除限制」默认全部关闭，开启前会先说明风险。Android 14 及以上还能用不打扰模式，在看不见的屏幕上操作，不耽误你用手机。
- **离线语音输入**：语音模型（约 241 MB）下载到手机上，在本地识别。
- **宠物**：Deepy 小鲸鱼和鲸娘陪你干活，打开「App 外显示」还能跟你到桌面。
- **分享**：把一条回复、选中的消息或整段对话分享成链接、图片、文件或文字；链接端到端加密，对方可以在浏览器里回放，或在 DSH Go 里接着聊。
- **外观**：六套配色，也可以跟随壁纸或自选颜色；换桌面图标，用自己的壁纸和启动画面；界面支持中文和英文。
- **匿名使用统计**：只发送每天的使用次数和 App、系统版本等基本信息，不含对话、文件和账号；默认开启，在 设置 › 隐私与分享 随时关闭。
- **图像与视频生成即将上线**：App 这边已经就绪，生成插件发布后即可在对话里使用。

此前 0.9.x 各版本的详细改动见[更新日志](https://github.com/ccch1mneyyy/dsh-go/blob/HEAD/docs/changelog.md)。

### English

DSH Go 1.0.0 is here, our first public release. It runs DeepSeek Harness (DSH) on your Android phone or connects to DSH on your computer or server, so you can pick up a chat or a task wherever you are. DSH Go is open source under AGPL-3.0; come take a look on GitHub. Thank you to everyone who reported problems and shared ideas during testing. If you're already on 0.9.10, nothing changes but the version number: it's the same app, now 1.0.0.

What DSH Go does today:

- **On your phone:** install the Ubuntu, Node.js and DSH runtime from the app, without Root or a separate Termux.
- **Remote hosts:** use DSH on a computer or server over SSH or DSH Remote; if you only connect remotely, the phone doesn't need the runtime.
- **Chat:** switch models, send images and step in while a reply is still coming; handle tool approvals and questions right in the chat, and switch between the native and web interfaces in one tap.
- **Plugins:** install from the plugin market; plugins adapted for DSH Go show up as native tool cards, forms and panels, with native settings pages too. The repository includes an SDK, guides and examples.
- **Phone control:** once you grant the permissions, the local engine can read the screen, tap and type, and you can pause or stop it at any time. Choose "Ask me at key steps" or "Fully automatic"; the optional Lift limits switches are all off by default and explain the risks before they turn on. On Android 14 and later, non-disruptive mode works on a hidden screen while you keep using your phone.
- **Offline voice input:** the voice model (about 241 MB) downloads to the phone and recognises speech on the device.
- **Pets:** Deepy and Whale girl keep you company while DSH works, and with "Show outside the app" they come along to the home screen.
- **Sharing:** share one reply, selected messages or a whole chat as a link, an image, a file or text. Links are end-to-end encrypted, and the recipient can replay the chat in a browser or continue it in DSH Go.
- **Appearance:** six colour palettes, or follow your wallpaper or pick your own colour; change the app icon and use your own wallpaper and launch screen. The app is available in Chinese and English.
- **Anonymous usage stats:** only daily usage counts and basics like the app and Android version, never chats, files or accounts. On by default; turn it off any time in Settings › Privacy and sharing.
- **Image and video generation is on its way:** the app side is ready, and it opens up in chats once the generation plugin is released.

For the detailed history of the 0.9.x releases, see the [changelog](https://github.com/ccch1mneyyy/dsh-go/blob/HEAD/docs/changelog.md).

## 0.9.10 · 2026-10-30

### 中文

- 手机操控：不打扰模式下输入文字，总是写进 AI 指定的那个输入框，并整体替换原来的内容；页面上有密码或验证码输入框、或者页面没能读全时，只给文字不附截图；英文界面的验证码、口令输入框也能认出来。「关键步骤先问我」在英文界面的发送、删除、付款、购买等按钮前也会先确认。
- 停止引擎时，正在进行的手机操作一起停下，排在后面的也不再执行。
- 语音模型下载完成后，已经打开的对话里马上出现麦克风，不用退出重进。
- 登录 DSH Remote：取消后不会再打开浏览器，也不会过一会儿变成已登录；退出登录后，各登录方式的按钮照常显示。
- 自己的启动动图：最后一帧按原本的时长显示完再进入 App，不再一闪而过。
- 选文件时超过大小或数量上限会马上提示，不再先把整个文件读完。
- 连接远程主机时，对话里图片的缩略图和预览同时下载，预览不再报读取失败。
- 应用内更新：下载时手机存储满了，会提示存储可能已满、清理后重试，不再一直卡在下载中。
- 首次安装后第一次运行期间导入的配置，不会被安全模式的「恢复上次正常的配置」当成正常配置。
- 使用说明：插件设置显示「未保存」时要点底部「保存」并等到「已生效」；DSH Remote 登录选和主机上相同的登录方式；停止分享后，4 秒撤销期过去、删除成功时链接才失效。

### English

- Phone control: in non-disruptive mode, typing always goes into the field AI asked for and replaces what was there. A page with a password or code field, or one that couldn't be read in full, comes back as text only, without a screenshot, and English code and passcode fields are recognised too. "Ask me at key steps" also asks before Send, Delete, Pay, Buy and similar buttons in English apps.
- Stopping the engine also stops the phone action in progress, and the ones queued behind it no longer run.
- When the voice model finishes downloading, the microphone appears in a chat that's already open, without leaving and coming back.
- Signing in to DSH Remote: after you cancel, the browser no longer opens later and you don't end up signed in anyway; after signing out, each provider's button shows again.
- Your own launch animation holds its last frame for its full time before the app takes over, instead of flashing past.
- Picking files stops at the size and count limits right away, instead of reading the whole file first.
- On a remote host, an image's thumbnail and its preview can download at the same time without the preview failing to load.
- In-app updates: running out of storage during the download now says storage may be full, so you can free up space and retry, instead of waiting forever.
- A config imported during the very first run after install is no longer taken as the last working configuration by Safe mode's "Restore the last working configuration".
- User guide: when plugin settings show Unsaved, tap Save at the bottom and wait for Applied; DSH Remote sign-in uses the same provider as on the host; after Stop sharing, the link stops working once it's deleted after the 4 s Undo window.

## 0.9.9 · 2026-10-30

### 中文

- 手机操控可以全程自动：首次启动选「手机操控」时，可以选「关键步骤先问我」或「全程自动」，之后在 设置 › 手机操控 › 确认方式 随时改，那里也列出了哪些事仍由你来操作。
- 解除限制（可选）：设置 › 手机操控 › 解除限制 有三个开关——系统设置、密码和验证码、DSH Go 自身，默认全部关闭。打开前会说明 AI 能做什么、可能出什么问题以及免责声明，需要按住「我了解风险，开启」约 1.5 秒，后果由你自行承担；任务进行中不能打开，关闭只要点一下。开着时悬浮条和手机操控页显示「已解除限制」。AI 输入的密码和验证码在操作记录、悬浮条和确认卡里只显示为 ••••，也不会出现在返回给模型的结果里。
- 自定义壁纸：设置 › 主题 › 壁纸 可以把自己的图片铺在首页、对话和抽屉后面，可以调模糊，浅色模式下提亮、深色模式下压暗；文字和背景的对比度始终保持在 4.5:1 以上。
- 启动画面：自己的启动画面不再限制 3 秒，图片和动图 8 MB 以内、视频 30 MB 以内，冷启动时完整播放，点一下就能跳过。换了桌面图标后，启动时只会出现你选的那个图标，不会先闪一下默认的蓝色图标。
- 直接启动本机引擎（设置 › 诊断 › 开发者选项）仍是实验功能，默认关闭。打开后，从旧版本升级的会先把插件文件整理一次，手机空间不够时先用兼容启动；某台手机上直接启动起不来（例如 Android 16 会拦截）时，会自动改用兼容启动，不进安全模式，也不会反复重试。
- 插件更新后提示重启引擎：正在运行的引擎要重启才会用上新版本，更新完成后直接给出重启的选项（连接远程主机时提示到那台电脑上重启）。
- 匿名使用统计：每天的使用次数（发消息、语音输入、手机操控、生成、分享各几次，装了几个插件），连同 App 和系统版本、CPU 架构、手机品牌（不含型号）、界面语言和本机引擎的启动方式，当天过后匿名发送一次；设备之间只用一个每 90 天更换的随机编号区分，不含对话、文件和账号。首次启动的欢迎页上就有开关，之后在 设置 › 隐私与分享 一键关闭，关闭后本机记下的次数和编号立即删除。从旧版本升级的会在首页提示一次。
- App 外的桌宠：拿起来、开心、醒来和打字时不再被裁掉；气泡放在桌宠画面的上方，不挡住动画，换动作时平滑跟着移动。
- 归档对话和卸载插件先等 4 秒，期间点「撤销」就原样保留，归档时进行中的一轮也不会停；切出 App 或接着归档、卸载别的时会立即执行。
- 陪你满半小时后，鲸娘会请你去 GitHub 给 DSH Go 点个 Star：一键打开仓库，点「已经点过啦」就不再出现；选「下次再说」的，累计再用 5 小时会再问一次，最多两次。只在首页或对话里、没有其他弹窗、当前对话也没有进行中的任务时出现。
- 远程主机登录 DSH Remote：服务器提供的每种登录方式都有自己的按钮，GitHub 排在最前（感谢 @HuanLinOTO）。
- 以前把新对话的默认权限设成「Auto」的，升级后本机引擎会清掉这个已失效的设置并重启一次，「本对话」和设置里的权限选项恢复正常。
- 其他：对话里 DSH 自己写进收件箱的提示不再显示成你发的消息；插件市场连不上时显示网络错误和重试，不再说「目录格式有误」；首次启动选了「桌宠与悬浮窗」而还没选桌宠时，会顺带选好默认桌宠；换了主机后，删除文件夹的「撤销」和批量置顶不会落到另一台主机上；语音「重新下载」时旧模型保留到新模型下载完；首次启动总结页的「继续」失败后可以再试；远程主机页的服务说明改为「服务由 liguobao/ds-harness-remote 提供」，点项目名可以打开它。

### English

- Phone control can run fully automatic: when you pick Phone control on first run, choose "Ask me at key steps" or "Fully automatic"; change it any time in Settings › Phone control › Confirmation, which also lists what still stays with you.
- Lift limits (optional): Settings › Phone control › Lift limits has three switches — system settings, passwords and codes, and DSH Go itself — all off by default. Turning one on first shows what AI can then do, what can go wrong and the disclaimer, and takes holding "I understand the risks, turn on" for about 1.5 s; you bear the risk. It can't be turned on while a task runs, and one tap turns it off. While any is on, the floating bar and the Phone control page say "Limits lifted". Passwords and codes AI types show only as •••• in the action log, the floating bar and confirmation cards, and never come back in the results sent to the model.
- Your own wallpaper: Settings › Theme › Wallpaper puts a picture of yours behind home, chats and the drawer, with Blur, plus Lighten in light mode and Dim in dark mode; text always keeps a contrast of 4.5:1 or more.
- Launch screen: your own launch screen is no longer capped at 3 s. Pictures and animations up to 8 MB and videos up to 30 MB play in full on a cold start, and a tap skips. After you change the app icon, launch only ever shows the icon you chose, never a flash of the default blue one first.
- Direct local engine launch (Settings › Diagnostics › Developer options) stays experimental and off by default. Turned on, an install upgraded from an earlier version first tidies its plugin files once, using compatible launch while the phone is short of space; on a phone where a direct start fails (Android 16 blocks it, for one), the app goes back to compatible launch on its own, without Safe mode or repeated retries.
- Plugin updates ask for an engine restart: the running engine keeps the old version until it restarts, so finishing an update offers the restart right there (on a remote host, it tells you to restart DSH on that computer).
- Anonymous usage stats: each day's counts (messages, voice inputs, phone control tasks, generations and shares, and installed plugins), with the app and Android version, CPU architecture, phone maker (not the model), app language and how the local engine started, go out anonymously once after the day ends. Devices are told apart only by a random ID that changes every 90 days; never chats, files or accounts. The switch is on the welcome screen on first run, and one tap in Settings › Privacy and sharing turns it off and deletes the counts and the ID on the phone at once. Installs updated from an earlier version are told once on the home screen.
- Pet outside the app: picked up, happy, waking or typing, it's no longer cut off; its bubble sits above the pet's picture instead of over it and glides along when the pose changes.
- Archiving a chat or uninstalling a plugin waits 4 s first: Undo keeps it as it was, a running turn included. Leaving the app, or archiving or uninstalling something else, carries it out at once.
- After half an hour together, the whale asks you to give DSH Go a Star on GitHub: one tap opens the repository, "Already starred" ends it for good, and "Maybe later" asks once more after another 5 hours of use — twice at most. It only appears on the home screen or in a chat, with no other dialog open and no task running in the current chat.
- Signing in to DSH Remote on the remote host page: each sign-in method the server offers gets its own button, GitHub first (thanks @HuanLinOTO).
- If the default permission for new chats was once set to Auto, the local engine clears that no-longer-valid setting after the update and restarts once, so the permission options in This chat and Settings load again.
- Other fixes: notes DSH writes into the inbox itself no longer look like your messages; when the plugin market can't connect it shows a network error with Retry instead of "Invalid directory format"; picking Pet over other apps on first run also picks the default pet if none was chosen; after switching hosts, a deleted folder's Undo and bulk pinning never land on the other host; Re-download in Voice input keeps the old model until the new one is in; a failed Continue on the first-run summary can be tried again; the remote host page now credits liguobao/ds-harness-remote, and tapping the project name opens it.

## 0.9.8 · 2026-10-29

### 中文

- 改名 DSH Go：桌面图标、最近任务、通知和系统设置里都叫 DSH Go。保存的图片在相册「DSH Go」，下载的文件在「下载/DSH-Go」；之前存的文件留在原处，旧对话里的文件卡片照常打开。
- 启动动画：系统启动画面无缝交接到 App 的第一帧，图标轻轻上移，DSH Go 字样随之浮现；冷启动完整播一遍，热启动可用即进。
- 自己的启动画面和桌面入口：设置 › 主题 › 启动画面 可以换成自己的图片、动图或 3 秒内的视频，选适配方式和背景色，预览一遍再用。桌面图标下新增「图片快捷方式」，用自己的图片在桌面另放一个打开 DSH Go 的入口。换桌面图标后会提示几秒后生效。
- 首次启动按功能开权限：新增一步「想让 DSH Go 帮你做哪些事」，在读写手机文件、桌宠与悬浮窗、手机操控、后台持续运行、语音输入里挑选，再逐项带你到对应的系统页面或品牌设置页，回到 App 自动确认是否已开启。无障碍遇到「受限制的设置」时有分步指引。之后在 设置 › 通用 › 系统权限 随时查看、补开。
- 离线语音输入：语音模型（约 241 MB）下载到手机上本地识别，不再依赖系统语音服务。设置 › 语音输入 可以下载、取消、重试和删除；国内网络直接可下，中断后接着下，用移动数据时先确认。首次启动选了语音输入的，引擎就绪后自动下载。
- 插件设置页：每个有设置项的插件都打开原生设置页，字段多时可以搜索，常用项在前，其余收进「高级」，离开前有未保存的改动会先确认。设置 › 引擎参数 › 插件 只列你装的插件，引擎自身的核心配置不在其中。
- 插件界面更丰富：对话里的 genui 卡片直接画成原生卡片，不再显示原始 JSON 和「让它重发」；插件视图新增空状态、图片墙、环形进度和指标趋势，可以跟随你选的配色，图标扩充到 162 个。输入框上方新增「插件」胶囊，打开本对话的插件面板；对话详情 › 插件 能打开插件提供的对话视图，打开前核对是不是你点的那一个；插件详情列出 App 里还没有位置的网页界面，一点直达网页版。
- 加号新增「本对话」：直接改这个对话的权限、开关计划模式，手机操控开着时还能改确认方式。选择模型弹层底部可以直达「管理模型」。
- 网页模式的返回键：先关掉网页里打开的弹窗、菜单、侧栏和子页面，一次一层，都关完才离开 App。
- SSH 连接的电脑上，用桌面版、终端或其他方式产生的对话，在列表里直接显示标题，不再是「未命名」；断线重连后也照常补上。
- 内置引擎升级到 DSH 0.2.1-rc.4：用 API Key 时模型列表跟随 DeepSeek 官方。所选模型需要新版引擎或当前不可用时，对话里直接说明并给出出路，不再只是「本轮出错了」。
- 图像与视频生成即将上线：App 这边已经就绪，生成插件发布后即可在对话里使用。
- 应用内更新更稳妥：屏幕上显示的版本、下载的文件和它的校验和绑定在一起，安装的一定是你看到的那个版本；安装前再次核对，不符的安装包直接丢弃，重试时按屏幕上的版本重新下载；放弃的安装不会影响下一次。
- 切换更稳：换主机后，旧主机的审批卡和提问卡随之收起，不再挡住新主机的请求；在选模型弹层打开期间换了对话，选中的模型不会落到别的对话；重连后计划、目标和团队信息会重新读取。
- 报错更清楚：订阅页的模型读不到时显示「没能读取模型」并可重试，不再误报「暂无模型」；团队消息读取失败不再显示成空收件箱；论坛通知翻页失败可重试；直接打开的 Bot 或群聊页会分别说明离线、经中转连接或 Bot 已不在。
- 其他：App 进入后台后，计时、动画和终端长按按键都会停下；进行中的提示语相邻两条不再重复；设置 › 诊断 显示引擎实际是直接启动还是兼容启动，直接启动失败后可以一键切回兼容启动，App 自身的异常也会记进诊断包；插件不能再通过界面操作改动权限模式；开源许可信息补全。

### English

- Now called DSH Go: the launcher, Recents, notifications and system settings all say DSH Go. Saved pictures go to the DSH Go album and downloads to Download/DSH-Go; files saved earlier stay where they are, and older chats still open their file cards.
- Launch animation: the system splash hands over seamlessly to the app’s first frame, where the icon rises and DSH Go fades in beneath it. A cold start plays it through; a warm start goes the moment the app is ready.
- Your own launch screen and home-screen picture: Settings › Theme › Launch screen takes a picture, an animation or a clip up to 3 s, with a fit and background colour and a preview first. Under App icon, Picture shortcut puts a separate shortcut to DSH Go on the home screen with a picture of your own. After switching the app icon, the app says the home screen takes a few seconds.
- Permissions by feature on first run: a new step, "What should DSH Go help with?", lets you pick from phone files, pet and floating window, phone control, running in the background and voice input. The app then takes you to each system or phone-maker page in turn and checks whether it's on when you come back. Accessibility gets step-by-step help when Android shows Restricted settings. Review or finish any of it later in Settings › General › System permissions.
- Offline voice input: the voice model (about 241 MB) downloads to the phone and recognises speech on the device, without relying on the system's speech service. Settings › Voice input downloads, cancels, retries and deletes it; it downloads from mainland China, resumes after an interruption and asks before using mobile data. If you picked voice input on first run, it downloads once the engine is ready.
- Plugin settings: every plugin with settings opens a native page. Long forms can be searched, the common fields come first and the rest fold under Advanced, and leaving with unsaved changes asks first. Settings › Engine parameters › Plugins lists only the plugins you installed, never the engine's own core settings.
- Richer plugin UI: genui cards in a chat draw as native cards instead of raw JSON and "Ask to resend". Plugin views gain empty states, galleries, ring progress and metric trends, can follow your colour palette, and have 162 icons to choose from. A Plugins capsule above the composer opens the chat's plugin sheet; Chat details › Plugins opens a plugin's view of the chat, checking it is the one you tapped; and plugin details list the web parts the app has no place for yet, each one tap from DSH Web.
- This chat, in the + panel: change this chat's permissions, turn plan mode on or off and, with phone control on, its confirmation style. The model sheet links straight to Manage models.
- Back in web mode closes what DSH Web has open, one layer per press (dialogs, menus, side panels, sub-pages), and only then leaves the app.
- On a computer reached over SSH, chats started in the desktop app, the terminal or anywhere else show their titles in the list instead of "Untitled chat", and keep getting them after a reconnect.
- The built-in engine is now DSH 0.2.1-rc.4: with an API key, the model list follows DeepSeek's official one. When the chosen model needs a newer engine or isn't available, the chat says so and offers a way forward instead of a bare "Something went wrong this turn".
- Image and video generation is on its way: the app side is ready, and it opens up in chats once the generation plugin is released.
- Safer in-app updates: the version on screen, the file downloaded and its checksum are bound together, so what gets installed is always the release you see. They're checked again right before installing; a package that doesn't match is discarded and Retry downloads the release on screen again; and an abandoned install can't affect the next one.
- Steadier switching: after a host change, the old host's approval and question cards close instead of covering the new host's requests; picking a model after switching chats never lands on the wrong chat; and a reconnect reads plans, goals and team details again.
- Clearer errors: a subscription whose models can't be read says "Couldn’t load models" with Retry instead of "No models"; team messages that fail to load no longer look like an empty inbox; a forum notification page that fails to load more can be retried; and a Bot or group page opened directly tells offline, relay and a Bot that's gone apart.
- Other fixes: timers, animations and held terminal keys stop when the app goes to the background; neighbouring progress lines no longer repeat; Settings › Diagnostics shows whether the engine started directly or in compatible mode, offers a one-tap switch back after a failed direct start, and the app's own errors go into the diagnostics bundle; plugins can no longer change the permission mode from their UI; and the open-source notices are complete.

## 0.9.7 · 2026-10-28

### 中文

- 设置重新整理：首页按 AI、能力、外观、通用、主机、帮助与关于分组，每一行直接显示当前状态。顶部新增搜索，旧名字、同义词都能搜到，点结果会直接跳到那一项；在抽屉里按住 ⚙ 也能进入搜索。新增「个性化」「界面」「隐私与分享」「关于 dsh-go」几页。
- 几处改名：模型渠道 → 模型，引擎 → 本机引擎，引擎设置 → 引擎参数，后台保活 → 后台运行，语音识别 → 语音输入；「自动执行命令」并入权限里的「完全权限」。抽屉身份栏的圆键改为「全部功能」，全部功能也重新分组。
- 分享卡片的二维码中间加上了 dsh-go 图标，并略微放大，截图压缩后也更好扫。链接太长、印出来扫不出的卡片不再放二维码。
- DS Bot：视图卡里的选择题和简单表单可以直接在 App 里作答提交；群聊断线或补读失败后会自动接上；全文弹层的字数加上千分位。
- 插件设置里 App 编辑不了的部分，统一显示一行「在网页版编辑此项」。插件卸载、更新、允许构建脚本时如果已经切换了主机，会提示「主机已切换，未执行」。
- 切换主机后，斜杠命令的结果、「本对话都允许」和用量统计都只作用于原来的主机和对话。

### English

- Settings, reorganised: the home page groups everything under AI, Capabilities, Appearance, General, Hosts, and Help and about, and each row shows its current state. Search at the top finds old names and synonyms and takes you straight to the setting; you can also hold ⚙ in the drawer to search. New pages: Personalization, Interface, Privacy and sharing, and About dsh-go.
- A few renames: Model providers → Models, Engine → Local engine, Engine settings → Engine parameters, Keep alive → Background running, Speech recognition → Voice input; "Run commands automatically" is now Full access under Permissions. The drawer's round button opens All features, which is regrouped too.
- Share cards carry the dsh-go icon in the middle of the QR code, a little larger so it still scans from a compressed screenshot. A card whose link is too long to scan no longer prints a code.
- DS Bot: answer choice questions and simple forms in view cards right in the app; group chats pick up again after a dropped feed or a failed catch-up read; and the full-text sheet groups its character count.
- Plugin settings the app can't edit show one "Edit this item on the web" row. Uninstalling, updating or allowing a plugin's build scripts after you've switched hosts now says "Host changed — nothing was done".
- After switching hosts, a slash command's result, "allow all in this conversation" and usage figures stay with the host and conversation they came from.

## 0.9.6 · 2026-10-28

### 中文

- 手机操控：在别的 App 里遇到需要你确认的操作，也会弹出 dsh-go 的确认卡；任务完成后回到发起它的那个对话，系统不允许自动切回时改用一条通知。手机操控 › 进阶 › 后台确认与返回，可以查看各品牌手机的设置方法。
- 插件设置原生化：多选、列表、日期、颜色、链接、滑块、折叠分组等都能直接在 App 里编辑，只有个别不支持的项会显示「在网页版编辑此项」。字段说明完整显示；保存要等主机确认，失败时保留你的输入。语音输入类插件有了自己的「语音设置」。
- 列表不再等引擎：模型、渠道、插件和对话列表在引擎启动或重连时先显示上次的结果，后台更新完成后替换；读取大列表时界面照常滑动。
- DS Bot：主机上的 DS Bot 还不支持手机端时会直接说明，并提供网页版入口；群聊达到转发上限后可以一键继续；可以为 Bot 或群聊选择工作目录、从详情页复制一个 Bot；主机还在统计用量时显示「—」而不是 0；刷新记忆时内容保留在屏幕上。
- 切换更稳：换对话或换主机后，迟到的结果不会落到别处，包括附件、撤回、分叉、重新回答、Bot 的回答与审批，以及插件的安装、卸载和更新。断线重连后，先同步完对话再允许发送。
- 输入：外接键盘在输入法上屏后按 Ctrl+Enter 即可发送，连按两次 Esc 停止；模型渠道的 Base URL 和联网搜索地址使用普通网址键盘。
- 其他：后台任务的通知显示为一行安静的状态，不再像你发出的消息；SSH 导入私钥限制在 64 KiB；定时任务读取系统时区更可靠；诊断包里记录网络（DNS）设置，便于排查连不上的问题。

### English

- Phone control: when an action needs your OK while you're in another app, dsh-go's confirmation card now appears there too. When a task ends you're taken back to the chat that started it, or, where the system doesn't allow that, you get a notification. Phone control › Advanced › Confirmations and return shows how to set this up on each phone brand.
- Native plugin settings: multi-select, lists, dates, colours, links, sliders and collapsible groups can all be edited in the app; only the odd unsupported field shows "Edit this item on the web". Field descriptions show in full, saves wait for the host to confirm, and a failed save keeps what you typed. Voice input plugins get their own Voice settings.
- Lists don't wait for the engine: models, providers, plugins and chats show their last result while the engine starts or reconnects, then update in place, and large lists load without stalling the screen.
- DS Bot: when the host's DS Bot isn't on mobile yet, the app says so and offers DSH Web. A group that hits its relay limit can carry on in one tap; Bots and groups can have a working folder; you can duplicate a Bot from its details; usage shows "—" rather than 0 while the host is still counting; and refreshing memory keeps it on screen.
- Steadier switching: after you change chats or hosts, late results never land somewhere else. That covers attachments, withdrawals, forks, regenerated replies, Bot answers and approvals, and plugin installs, uninstalls and updates. After a reconnect, the chat syncs before you can send.
- Typing: with a hardware keyboard, Ctrl+Enter sends after an IME commit and pressing Esc twice stops; a provider's Base URL and web search addresses get a normal URL keyboard.
- Other fixes: background task notices show as a quiet status line instead of looking like your own message; SSH private key imports are capped at 64 KiB; schedules read the phone's time zone more reliably; and the diagnostics bundle records network (DNS) settings to help track down connection problems.

## 0.9.5 · 2026-10-27

### 中文

- 分享重新设计：消息下方的「分享」打开同一个面板，选好范围（这条回复、选中的消息、整段对话），再选链接、图片、文件或文字。是否包含思考过程、工具调用和图片只设一次，对每种方式都生效。「我的分享链接」随时可以管理和停止分享。点赞和点踩已移除。
- 首次启动更快上手：选择在本机运行后，运行环境在后台准备，同时就能挑外观、连接 DeepSeek；进度一直显示在底部，完成后自动进入。
- 设置 › 界面新增「性能」：自动、完整、轻量。配置较低或手机发热时自动减少模糊与动效，降温后恢复。
- 语音输入更可靠：系统语音识别出错时自动改用引擎转写；可以在设置 › 对话 › 语音识别里选择方式，出错时提示具体原因。
- 对话页：内容不满一屏时从顶部开始，往上翻不再有大片空白；一轮结束时过程收起不再跳动。
- 宠物悬浮窗不会再出现两只；停止和发送只作用于当前连接，重连后也能正常停止。
- 弹出面板只保留一种关闭方式：能下拉的只有顶部把手，编辑类保留 ×；有未保存的输入时，下拉会先确认。
- 插件：原生界面支持更丰富的文字样式与配色，以及输入框、滑块、开关、下拉、日期、评分、表单、页签、折叠等控件；插件可以请你选择文件或图片；插件详情显示加载状态与原因；本地插件可以一键重载；会话页签里能直接打开插件的网页面板。
- 其他：大字号下恢复选项完整显示；本机运行环境无法启动时直接说明原因；空工作区会提示旧对话在「全部对话」里。

### English

- Sharing, redesigned: Share under a message opens one panel. Pick what to share (this reply, selected messages or the whole chat), then a link, an image, a file or text. Whether to include thinking, tool calls and images is set once and applies to every option. My shared links lets you manage or stop sharing at any time. Like and dislike are gone.
- A faster first run: after you choose to run on this phone, the runtime gets ready in the background while you pick a look and connect DeepSeek. Progress stays at the bottom, and the app opens by itself when it's done.
- Settings › Interface › Performance: Auto, Full or Light. On lower-end or hot phones, blur and motion ease off automatically and come back when it cools down.
- More dependable voice input: when the system recognizer fails, the app switches to engine transcription. Choose the method in Settings › Chat › Voice recognition; errors now say what went wrong.
- Chats: a short chat starts at the top, with no empty space when you scroll up, and a finished turn folds away without a jump.
- The pet overlay no longer shows up twice, and Stop and Send act on the current connection, so stopping still works after a reconnect.
- Sheets close one way: draggable sheets have just the handle, editing sheets keep ×, and dragging away unsaved input asks first.
- Plugins: native views get richer text styles and colours plus text fields, sliders, switches, dropdowns, dates, ratings, forms, tabs and collapsible sections; plugins can ask you to pick a file or photo; plugin details show load status and why; local plugins reload in one tap; and a session's tab can open a plugin's web panel.
- Other fixes: recovery options show in full at large text sizes; a local runtime that can't start says why; and an empty workspace points to All chats for earlier chats.

## 0.9.4 · 2026-10-27

### 中文

- 网页模式更跟手：弹出键盘不再卡顿，侧栏开合更快。
- 打开 App 更快，引擎和界面同时启动。
- 远程主机连接更可靠：兼容新版 DSH Remote 服务端，用加密私钥连接 SSH 时界面不再卡住，版本不匹配时直接提示更新；远程主机页可以关闭「连接上次使用的主机」。
- 工具读取的图片和手机截图，展开卡片就能看到缩略图。
- 在手机共享存储里新建文件不再失败；手机操控不会因为别的对话结束而提前收起或跳回 App。
- 对话里：提问卡可以选「不回答」，斜杠命令只显示一行，被插件接走的消息不再一直显示发送中，回到底部的按钮不再闪烁，横屏打字时总留着一段对话。
- 插件与模型：插件开关在列表重排后不再错位，部分插件的设置页不再空白，自定义渠道里的同名模型不再被误认成已选中。
- 其他修复：代码里的 <=、-> 不再连成一个符号；看图时顶栏不再出现灰块；新对话的默认权限不再存成只对当前对话有效的「自动」；消息里的文件链接和图片打开的是正确的文件；引擎启动卡住时会停下并说明原因。

### English

- Web mode feels snappier: the keyboard no longer stutters, and the sidebar opens and closes faster.
- The app opens faster: the engine starts alongside the interface.
- More reliable remote hosts: works with newer DSH Remote servers, SSH with an encrypted private key no longer freezes the app, and a version mismatch tells you what to update. You can turn off Connect to the last host on the remote hosts page.
- Images read by tools and phone screenshots show as thumbnails when you expand the card.
- Creating files in the phone's shared storage no longer fails, and phone control no longer wraps up or jumps back to the app when a different chat finishes.
- In chats: question cards can be skipped, a slash command shows as one row, a message a plugin picked up no longer stays "sending", the jump-to-bottom button no longer flickers, and typing on a phone on its side always leaves a strip of chat.
- Plugins and models: plugin switches stay with their plugin when the list reorders, some plugin settings pages are no longer blank, and a model with the same name in a custom provider no longer looks selected.
- Other fixes: <= and -> in code no longer merge into one symbol; the image viewer's top bar no longer shows a grey block; the new-chat default permission can no longer be saved as the current-chat-only Auto; file links and images in messages open the right file; and an engine stuck while starting stops and tells you why.

## 0.9.3 · 2026-10-26

### 中文

- 插件可以直接朗读回复，你一开口就停下，还能显示字幕。
- 内置使用说明：直接问 App 里的 AI 怎么用，回答里一点就跳到对应页面。
- 静止时更省电：历史命令不再一直转圈，宠物隐藏时不再走帧。
- 手机操控暂停后不再自动恢复，等你点「继续」。
- 消息里的文件链接可以点开；写成 example.com 的网址在浏览器打开。
- 其他修复：分叉后的提示不再挡住输入框，切换语言后插件文字立即更新。

### English

- Plugins can read replies aloud, stop the moment you start talking, and show captions.
- A built-in guide: ask the AI in the app how anything works, then tap straight to the right page.
- Less battery drain at rest: the command history no longer spins forever, and a hidden pet no longer draws frames.
- Paused phone control no longer resumes on its own; it waits for you to tap Continue.
- File links in messages now open, and addresses written like example.com open in your browser.
- Other fixes: the notice after branching a chat no longer covers the composer, and plugin text follows a language change right away.

## 0.9.2 · 2026-10-26

### 中文

- 插件可以直接用原生界面呈现：工具结果卡片、输入框上方的快捷按钮和状态条、消息长按菜单里的插件操作，以及对话详情和全部功能里的插件面板。
- 手机操控的悬浮条默认常驻，闲置时自动变淡，也可以手动收起；自动收成小球改为可选。
- 「已复制」「已保存」这类提示更短，看一眼就走。
- 在 App 里直接检查并安装内测更新。
- 其他打磨：宠物站在输入框上方最上面那一条；让 AI 装好的插件，回复一结束就能用。

### English

- Plugins can now show up natively: tool result cards, quick buttons and a status line above the composer, actions in a message's long-press menu, and plugin panels in chat details and All features.
- The phone-control floating bar now stays put by default, fades when idle and can be tucked away by hand; folding into a small ball is now optional.
- Confirmations like "Copied" and "Saved" are shorter and get out of the way.
- Check for and install beta updates right in the app.
- More polish: your pet stands on the topmost bar above the composer, and a plugin the agent installs is ready as soon as the reply ends.

## 0.9.1 · 2026-10-25

### 中文

- 「模型渠道」里自己添加的模型，可以逐个设置上下文长度、最大输出、输入类型和思考档位。
- 手机操控时，悬浮条闲置一会儿就缩成小球，不挡屏幕；任务完成后自动回到对话，悬浮条一并收起。
- 首次使用可以只连远程主机，手机上不必安装运行环境；本机运行环境随时可以在设置里安装或卸载。
- 其他细节修复与打磨。

### English

- Models you add under Model providers can each have their own context length, max output, input types and thinking levels.
- During phone control, the floating bar shrinks to a small ball when idle, out of your way. When a task is done, you're back in the chat and the bar tucks away.
- On first launch you can connect to a remote host alone, with nothing to install on the phone. Install or remove the on-device runtime any time in Settings.
- Smaller fixes and polish.

## 0.9.0 · 2026-10-25

### 中文

**宠物**

- Deepy 小鲸鱼和鲸娘住进 App，趴在输入框和思考条上，干活、等你确认、完成时各有动作和气泡。
- 打开「App 外显示」，宠物跟着你到桌面；有事冒个气泡，点一下直达那段对话。

**网页模式**

- 原生界面和网页版一键切换，下次打开停在你上次用的那个。
- 网页版里也有 App 的按键，通知、分享、切换主机都落在同一段对话上。

**横屏与平板**

- 横屏手机和平板重新排版：内容居中限宽，弹窗和分享预览按屏宽排布，横屏弹出键盘也不挤。
- 网页版横屏用官方桌面布局，避开刘海和手势条。

**English**

- 全部界面支持英文，在设置里切换，默认跟随系统。

**主题与图标**

- 全新 App 图标，界面图标整套重绘。
- 六套主题色：雾蓝、黛青、暮紫、松石、琥珀、石墨，也可以跟随壁纸或自选颜色。
- 四款桌面图标：雾蓝、夜幕、霜白、墨。
- 功能磁贴三种风格：扁平双色、极简几何、玻璃渐变。

**对话**

- 回复中途也能插话：消息先排队，点「立即发送」就打断当前回复。
- 停下时，排队的消息马上发出；没送达的标为「未发送」，可以再发或撤回。
- 过程自动折叠，插过话的回合也分段收好；长对话的过程不再缺失。

**分享**

- 分享卡片带上消息里的图片，五种模板：浅色、深色、卡片、纸张、玻璃；多轮对话可以拼成一张长图。
- 整段对话可以分享成文件或链接，对方在浏览器里回放，或在 dsh-go 里接着聊。链接端到端加密，在「我的分享链接」里管理。

**更稳**

- 系统省电拦住后台时，App 会提醒，并直达对应的放行设置，vivo、小米、华为、荣耀、OPPO 都有。
- 重置引擎默认保留界面配置和技能，已装插件和设置也可以一并保留。
- 插件的网页界面可以直接嵌在 App 里打开。
- 本机网页版只接受 App 自己的访问。

### English

**Pets**

- Deepy and Whale girl now live in the app. They perch on the composer and the thinking bar, and react when DSH is working, needs you, or is done.
- Turn on "Show outside the app" and your pet comes along to the home screen. It pops a bubble when something needs you; one tap takes you to that chat.

**Web mode**

- Switch between the native and web interfaces in one tap. The app reopens in whichever you used last.
- The web interface has the app's keys too, and notifications, sharing and host switching all land on the same chat.

**Landscape and tablets**

- New layouts for landscape phones and tablets: content stays centered, dialogs and share previews use the width, and the keyboard no longer crowds a landscape screen.
- The web interface uses the official desktop layout in landscape and keeps clear of the notch and gesture bar.

**English**

- The whole app is now available in English. Switch in Settings; by default it follows your system.

**Themes and icons**

- A new app icon, and every icon in the app redrawn.
- Six accent colors: Mist, Teal, Dusk, Aqua, Amber and Slate. Or match your wallpaper, or pick your own.
- Four home screen icons: Mist blue, Nightfall, Frost white and Ink.
- Three feature tile styles: Duotone, Geometric and Glass.

**Chats**

- Chime in while DSH is replying. Your message waits its turn, or tap "Send now" to interrupt.
- Stopping sends queued messages right away. Anything that didn't get through is marked "Not sent", ready to send again or withdraw.
- Process steps fold away on their own, including turns you chimed into, and long chats keep every step.

**Sharing**

- Share cards now include the message's images and come in five templates: Light, Dark, Card, Paper and Glass. Several rounds can be stitched into one long image.
- Share a whole chat as a file or a link. Others replay it in the browser or pick it up in dsh-go. Links are end-to-end encrypted; manage them in "My shared links".

**More reliable**

- When the system's battery saver holds DSH back in the background, the app tells you and opens the right setting, on vivo, Xiaomi, Huawei, Honor and OPPO.
- Resetting the engine keeps your interface settings and skills, and can keep installed plugins and settings too.
- Plugin web interfaces open right inside the app.
- The local web interface only answers to the app itself.
