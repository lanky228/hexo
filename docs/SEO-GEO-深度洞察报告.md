# SEO + GEO 深度洞察报告

> 💡 本报告是对博客技术SEO和生成引擎优化(GEO)的全面诊断，覆盖基础设施、内容层、外部信号三个维度，含具体执行方案。

## 一、现状总览

| 维度 | 现状 | 评分 |
|------|------|------|
| 技术SEO基础设施 | sitemap✓ / feed✓ / URL已修复✓ / robots.txt✓ / llms.txt✓ / JSON-LD✓ | 7/10 |
| 内容SEO | 26篇文章中25篇缺description，14篇tags全部是"AI" | 2/10 |
| 外部信号 | 0外链、0社交链接、0收录提交 | 0/10 |
| GEO就绪度 | robots.txt允许AI爬虫✓ / llms.txt✓ / 结构化数据✓ | 6/10 |

**核心问题**: 基础设施已就位，但内容层和外部信号严重缺失。搜索引擎和AI引擎能爬到页面，但抓不到有价值的结构化信息。

## 二、技术SEO审计

### 2.1 已具备 ✓
- **Sitemap**: hexo-generator-sitemap + hexo-generator-baidu-sitemap 已安装，生成 sitemap.xml 和 baidusitemap.xml
- **RSS Feed**: hexo-generator-feed 已安装，生成 atom.xml 和 rss2.xml
- **URL结构**: permalink 使用 `:year/:month/:day/:title/`，对SEO友好
- **域名**: 已从 coding-pages 修正为 lanky228.github.io
- **robots.txt**: 已配置，允许所有AI爬虫
- **llms.txt**: 已创建，包含15篇技术文章的结构化摘要
- **JSON-LD结构化数据**: WebSite + BlogPosting + BreadcrumbList + FAQPage 四类Schema
- **meta description/keywords**: 站点级已配置

### 2.2 缺失项 ✗

| 缺失项 | 影响 | 优先级 | 修复方案 |
|--------|------|--------|----------|
| 文章级description | 搜索结果摘要不可控，AI引擎无法提取摘要 | P0 | 每篇文章front matter添加description |
| 社交链接未配置 | NexT主题社交链接全注释，E-E-A-T信号缺失 | P1 | 取消注释GitHub等社交链接 |
| 404页面缺失 | 用户和爬虫访问无效URL时无引导 | P1 | 创建自定义404页面 |
| canonical标签 | NexT未默认输出canonical，可能产生重复内容问题 | P2 | 在head.swig中添加canonical link |
| Open Graph标签 | 社交分享时无预览卡片 | P2 | 在head.swig中添加og:title/og:description/og:image |
| RSS Feed未提交 | Feedburner/Google Search Console未收录 | P2 | 提交RSS到搜索引擎 |
| 页面加载性能 | 未压缩CSS/JS，无lazy load | P3 | hexo-neat压缩 + 图片懒加载 |

### 2.3 canonical 和 Open Graph 补丁（建议追加到 head.swig）

```html
{# Canonical URL #}
<link rel="canonical" href="{{ config.url }}{{ page.path }}" />

{# Open Graph #}
<meta property="og:site_name" content="{{ config.title }}" />
<meta property="og:title" content="{{ page.title || config.title }}" />
<meta property="og:description" content="{{ page.description || config.description }}" />
<meta property="og:url" content="{{ config.url }}{{ page.path }}" />
<meta property="og:type" content="{{ page.title ? 'article' : 'website' }}" />
<meta property="og:locale" content="zh_CN" />

{# Twitter Card #}
<meta name="twitter:card" content="summary" />
<meta name="twitter:title" content="{{ page.title || config.title }}" />
<meta name="twitter:description" content="{{ page.description || config.description }}" />
```

## 三、内容SEO诊断

### 3.1 标签问题（最严重）

当前标签分布：
- `tags: AI` → 14篇文章（占技术文章93%）
- `tags: 物理` → 4篇
- `tags: 计算机` → 3篇
- `tags: 社会` → 2篇
- `tags: 游戏` → 1篇

**问题**: "AI"作为唯一标签没有任何语义区分度。14篇覆盖ClickHouse、Snowflake、DuckDB、Claude Code等完全不同主题的文章共享一个标签，搜索引擎无法建立主题聚类。

**修复方案**: 每篇文章使用3-5个语义化标签，建立主题聚类：
- 数据库类: ClickHouse, OLAP, 列式存储, 数据库选型
- 湖仓类: Apache Iceberg, 数据湖, 湖仓, Trino
- AI编程类: Claude Code, Code Agent, MCP, AI编程
- 语义层类: 语义层, dbt, Cube, Text-to-SQL

### 3.2 Description缺失

25/26篇文章无description。影响：
- Google搜索结果使用自动提取的文本，通常不理想
- AI引擎（ChatGPT/Perplexity）无法在摘要中准确引用
- 社交分享时无预览描述

### 3.3 内容深度与原创性（优势）

博客的原创数据和分析是核心SEO资产：
- TPC-DS benchmark原创数据（Iceberg性能对比4场景）
- 具体产品对比矩阵（15+数据库/工具横向评测）
- 有具体数字和结论（如"ClickHouse单表聚合快3倍，多表JOIN是短板"）

**建议**: 进一步利用原创数据优势，添加结构化的对比表格（搜索结果富摘要可提取）。

### 3.4 内部链接网络

当前文章间几乎无内链。26篇文章形成26个孤岛，PageRank无法传递。

**修复方案**: 每篇文章添加2-3个相关内链，构建主题聚类内链网络：
- 数据库集群: ClickHouse ↔ Pinot ↔ DuckDB ↔ SingleStore
- 湖仓集群: Iceberg ↔ Trino ↔ Databricks
- 语义层集群: dbt/Cube ↔ Snowflake ↔ BigQuery/Looker ↔ Databricks
- AI编程集群: Claude Code ↔ AI编程实践 ↔ 统一SQL查询

## 四、GEO（生成引擎优化）策略

### 4.1 为什么GEO重要

传统SEO优化Google/Bing爬虫，GEO优化AI引擎爬虫（GPTBot、PerplexityBot、Claude-Web等）。当用户在ChatGPT/Perplexity中提问"ClickHouse和StarRocks怎么选"，AI引擎会检索已爬取的内容生成回答。

### 4.2 GEO核心要素

| 要素 | 当前状态 | 目标状态 |
|------|----------|----------|
| AI爬虫访问 | ✓ robots.txt已允许 | 维持 |
| 结构化摘要 | ✓ llms.txt已创建 | 持续更新 |
| FAQ格式 | ✗ 无FAQ内容 | 每篇技术文3-5个Q&A |
| 引用友好性 | ✗ 无明确数据引用格式 | 关键数据加粗+结构化表格 |
| 实体明确性 | ✗ 无明确实体标注 | JSON-LD已定义author/publisher |
| 可引用性 | ✓ 原创数据丰富 | 添加"数据来源"标注 |

### 4.3 AI引擎偏好内容特征

基于当前研究和实践观察，AI引擎更倾向于引用：
1. **有明确数字和结论的内容** — "快3倍"、"准确率97%"比"性能更好"更易被引用
2. **对比表格** — 结构化对比矩阵可被直接提取
3. **FAQ格式** — Q&A直接匹配用户提问模式
4. **权威外链** — 链接到官方文档增加可信度
5. **更新时间标注** — AI引擎偏好时效性强的内容

### 4.4 llms.txt 维护策略

llms.txt 是 2024 年提出的标准（类似 robots.txt 但面向 LLM），让 AI 引擎快速理解站点内容结构。

维护原则：
- 新文章发布时同步更新 llms.txt
- 每条包含：标题 + URL + 一句话摘要（含关键数据）
- 按主题分类组织

## 五、外部信号策略

### 5.1 搜索引擎收录提交

| 平台 | 提交入口 | 状态 |
|------|----------|------|
| Google Search Console | https://search.google.com/search-console | 待提交（需验证域名所有权） |
| Bing Webmaster Tools | https://www.bing.com/webmasters | 待提交 |
| 百度站长平台 | https://ziyuan.baidu.com | 待提交（hexo-baidu-url-submit已安装） |
| IndexNow | 通过Bing/百度API即时推送 | 待配置 |

### 5.2 外链建设路线

| 策略 | 可行性 | 预期效果 |
|------|--------|----------|
| 技术社区分享（掘金/V2EX/知乎） | 高 | 引流+外链 |
| GitHub README反向链接 | 高 | 在相关项目README中引用benchmark数据 |
| Apache项目邮件列表 | 中 | 在Iceberg/Calcite讨论中引用分析 |
| 技术媒体投稿 | 中 | InfoQ/CSDN投稿获取高质量外链 |
| 学术引用 | 低 | 如果数据被论文引用，外链质量极高 |

### 5.3 社交链接配置

NexT主题社交链接全被注释。建议启用：
```yaml
social:
  GitHub: https://github.com/lanky228 || fab fa-github
  E-Mail: mailto:1289206629@qq.com || fa fa-envelope
```

## 六、执行优先级

### P0 — 立即执行（1-2天）
1. ✅ URL修复（coding-pages → lanky228.github.io）
2. ✅ robots.txt（允许AI爬虫）
3. ✅ llms.txt（AI引擎结构化摘要）
4. ✅ JSON-LD结构化数据注入
5. ✅ 站点级description/keywords
6. ⏳ 文章级description + 标签精细化（OpenCode执行中）
7. ⏳ FAQ段落添加（OpenCode执行中）
8. ⏳ 旧文章noindex（OpenCode执行中）

### P1 — 本周完成（3-5天）
9. canonical标签 + Open Graph标签
10. 社交链接配置
11. 404页面
12. 内部链接网络构建（OpenCode执行中）
13. 外链补充（OpenCode执行中）

### P2 — 本月完成（1-2周）
14. Google Search Console提交
15. Bing Webmaster提交
16. 百度站长平台提交
17. 技术社区分享（掘金/V2EX）
18. CSS/JS压缩（hexo-neat）

### P3 — 持续优化
19. 图片懒加载
20. 外链建设（GitHub README引用）
21. 定期更新llms.txt
22. 监控搜索表现（Search Console数据）

## 七、预期效果

### 短期（1个月）
- Google/Bing收录所有技术文章
- AI引擎可爬取llms.txt获取站点结构
- 搜索结果显示description摘要而非随机文本
- FAQ内容可能在搜索结果中展示富摘要

### 中期（3个月）
- 标签聚类形成主题权威性
- 内链网络提升PageRank传递
- 技术社区分享带来初始外链
- AI引擎在相关查询中开始引用博客内容

### 长期（6个月+）
- "ClickHouse vs StarRocks"等长尾查询排名提升
- TPC-DS benchmark原创数据成为引用来源
- 博客成为数据库/湖仓/AI编程领域的可引用资源

## 八、风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| GitHub Pages访问不稳定（中国） | 中 | 高 | 可配置CDN或迁移到Vercel/Cloudflare Pages |
| AI引擎不爬取GitHub Pages | 低 | 高 | 提交到Google Search Console间接被AI引用 |
| 标签过度优化被判定spam | 低 | 中 | 标签自然语义化，每篇3-5个，不堆砌 |
| 内容被AI引擎抓取但不引用 | 中 | 中 | 确保FAQ和结构化数据匹配常见查询模式 |

---

*报告生成时间: 2026-07-30*
*基于 lanky228.github.io 博客现状分析*
