# GEO/SEO 优化归档

> 最后更新: 2026-08-01
> 状态: ✅ 全部完成并部署

## 一、修改清单（主题升级安全）

所有修改均在 `themes/next/` 目录外，NexT 主题升级不会破坏任何修改。

| # | 文件 | 位置 | 主题升级安全 | 内容 |
|---|------|------|:---:|------|
| 1 | `_config.yml` | 博客根 | ✅ | `url: https://lanky228.github.io` |
| 2 | `source/_data/head.swig` | source/_data/ | ✅ | WebSite + Person schema (NexT 自定义注入点) |
| 3 | `scripts/seo-json-ld.js` | scripts/ | ✅ | BlogPosting + BreadcrumbList + FAQPage JSON-LD 生成 |
| 4 | `source/robots.txt` | source/ | ✅ | 允许 AI 爬虫 (GPTBot/ClaudeBot/PerplexityBot等) |
| 5 | `source/llms.txt` | source/ | ✅ | AI 引擎专用索引文件 |
| 6 | `source/_posts/*.md` (19篇) | source/_posts/ | ✅ | front matter + AI Summary + 参考链接 |
| 7 | `docs/GEO-SEO-洞察报告.md` | docs/ | ✅ | 原始诊断报告 |
| 8 | `docs/GEO-SEO-归档.md` | docs/ | ✅ | 本文档 |

## 二、各文件详解

### 2.1 `_config.yml`
```yaml
url: https://lanky228.github.io
```
**原理**: 域名统一是 SEO 基础，避免搜索引擎认为有重复内容。

### 2.2 `source/_data/head.swig` — WebSite + Person Schema
NexT 主题的自定义注入点（`source/_data/head.swig`），通过 `next_inject` 机制注入到 `<head>` 中。

生成 2 个 JSON-LD block:
- **WebSite**: 站点名称、URL、描述
- **Person**: 作者信息 + `knowsAbout`（11个专业领域，GEO 关键信号）

**注意**: BlogPosting 等 schema 不放在这里，因为 Swig partial 会被缓存，`page.tags` 等变量无法逐页求值。改用 `scripts/seo-json-ld.js` 生成。

### 2.3 `scripts/seo-json-ld.js` — 文章级 JSON-LD
Hexo 脚本，通过 `hexo.extend.filter.register('after_post_render', ...)` 钩子注入。

生成 3 个 JSON-LD block:
- **BlogPosting**: headline, author, datePublished, dateModified, description, keywords (从 `data.tags` 提取)
- **BreadcrumbList**: 首页 → 文章标题（面包屑导航）
- **FAQPage**: 自动从文中 `## FAQ` / `## 常见问题` 标题后的 `### Q:` 格式提取 Q&A 对

**关键设计决策**: 
- 使用 Hexo filter 而非 Swig 模板，因为 partial 缓存导致 `tag.name` 在模板上下文中为空
- `data.tags` 在 filter 中可以正确访问
- JSON-LD 直接注入到 HTML `</body>` 前

### 2.4 `source/robots.txt`
允许主流 AI 爬虫抓取：
- GPTBot (OpenAI)
- ClaudeBot (Anthropic)
- PerplexityBot
- Google-Extended
- Bytespider (字节跳动)
- CCBot (Common Crawl)

### 2.5 `source/llms.txt`
AI 引擎专用索引，列出所有技术文章标题+链接+简述。类似 sitemap 但面向 LLM。

### 2.6 文章修改（19篇技术文章 + 10篇旧内容）

每篇技术文章修改：
1. **AI Summary 块**: 文章开头 `<details><summary>📝 AI 摘要</summary>` 折叠块，内容取自 front matter `description`
2. **参考链接区**: 文末 `## 参考链接`，5-8个权威外链（官方文档/Wikipedia/论文）
3. **FAQ 格式**: `## FAQ` 下 `### Q: 问题` / `A: 回答` 格式（已有19篇）

10篇2020年旧内容：
- front matter 添加 `noindex: true`，搜索引擎不索引

## 三、P0 问题修复对照

| P0 | 问题 | 修复前 | 修复后 |
|----|------|--------|--------|
| P0-1 | 域名不统一 | coding-pages 旧域名 | lanky228.github.io |
| P0-2 | 零结构化数据 | 0 JSON-LD | 5 blocks/篇 |
| P0-3 | 无 robots.txt | 不存在 | 含 AI 爬虫允许 |
| P0-4 | 零外链 | 2/29 篇 | 20/29 篇, 126条 |
| P0-5 | 无 Q&A 格式 | 0 篇 | 19/29 篇 |
| P0-6 | 标签太泛 | AI-only | 29/29 篇多标签 |

## 四、JSON-LD 结构化数据架构

每篇技术文章生成 5 个 JSON-LD block：

```
1. WebSite        — 站点级 (source/_data/head.swig)
2. Person         — 作者级 (source/_data/head.swig)  
3. BlogPosting    — 文章级 (scripts/seo-json-ld.js)
4. BreadcrumbList — 面包屑 (scripts/seo-json-ld.js)
5. FAQPage        — 问答级 (scripts/seo-json-ld.js, 仅FAQ文章)
```

## 五、主题升级安全分析

NexT 主题升级场景分析：

| 升级方式 | 风险 | 说明 |
|---------|------|------|
| 下载新版覆盖 `themes/next/` | ✅ 安全 | 所有修改在 `source/` 和 `scripts/` |
| npm 更新 nexT | ✅ 安全 | 同上 |
| NexT 更改 `next_inject` 机制 | ⚠️ 低风险 | `source/_data/head.swig` 可能失效 |
| Hexo 更改 filter API | ⚠️ 极低风险 | `scripts/seo-json-ld.js` 可能需要适配 |

**恢复指南**（如果 `source/_data/head.swig` 注入失效）:
1. 检查 NexT 文档的 custom data 注入点名称
2. 如果 NexT 移除了 `head.swig` 注入，改用 `scripts/` 下的 Hexo filter 注入 WebSite/Person schema
3. 参考本文档的 schema 内容

## 六、部署流程

```bash
# 1. 临时改 _config.yml deploy 配置
cp _config.yml _config.yml.bak
# 用 patch 工具改 deploy repo 为 HTTPS+token

# 2. 构建部署
npx hexo clean && npx hexo generate && npx hexo deploy

# 3. 恢复配置
cp _config.yml.bak _config.yml
```

## 七、验证方法

```bash
# 检查 JSON-LD 是否渲染
grep -c 'application/ld+json' public/<article-path>/index.html
# 应返回 5 (或 4 如果无 FAQ)

# 检查 robots.txt
cat public/robots.txt

# 检查 llms.txt  
cat public/llms.txt

# 检查 noindex
grep -l 'noindex' public/2020/*/index.html
```
