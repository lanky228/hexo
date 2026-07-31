#!/bin/bash
# Blog GEO+SEO Content Optimization - Part A Retry
# Process articles in small sequential batches

cd /root/workspace/hexo-blog
LOG=/root/workspace/hexo-blog/run-geo-seo-partA.log
echo "=== Part A Retry Started ===" > $LOG
date >> $LOG

# Batch 1: Articles 1-4
echo "--- Batch 1: AI编程, Apache Pinot, BigQuery, Claude Code ---" >> $LOG
opencode run "请对 /root/workspace/hexo-blog/source/_posts/ 目录下以下4篇文章执行SEO优化。每篇文章做3件事：

1. 在front matter的tags行下面添加description字段（160字以内，含关键数据点）
2. 将tags从'AI'改为3-5个语义化标签（数组格式）
3. 在文章的'## 总结'或'## ✅ 总结'段落之前插入FAQ段落（3个Q&A）

FAQ格式：
## 常见问题

**Q: 问题？**

A: 回答。

**Q: 问题？**

A: 回答。

**Q: 问题？**

A: 回答。

文章1: AI编程实践洞察与工程原则.md
- description: AI生成代码的信任问题不是能不能看懂而是怎么证明它对了。差分测试、规格驱动、确定性护栏等方法论的ROI分析。
- tags: [AI编程, Code Agent, 差分测试, 软件工程]
- FAQ: AI生成代码怎么验证正确性? / 差分测试适用什么场景? / 规格驱动开发是什么?

文章2: Apache-Pinot-实时OLAP洞察.md
- description: Apache Pinot靠Star-Tree预聚合和原生实时Upsert，用户面分析比Druid低2-7倍延迟。含技术路线选型建议。
- tags: [Apache Pinot, OLAP, 实时分析, Druid, Star-Tree]
- FAQ: Pinot和Druid怎么选? / Star-Tree索引是什么? / Pinot支持Upsert吗?

文章3: BigQuery-Looker-Gemini洞察.md
- description: LookML运行14年最成熟的语义建模语言，Gemini用AI生成语义查询加确定性编译SQL把准确率从80%提升到97%。
- tags: [BigQuery, Looker, LookML, 语义层, Gemini]
- FAQ: LookML是什么? / Gemini怎么提升SQL准确率? / Looker的语义层有什么优势?

文章4: Claude-Code-开源代码与Code-Agent技术洞察.md
- description: Claude Code以1730行异步生成器为核心agentic loop，40+自描述工具，四层上下文压缩，开源Code Agent工程化程度最高。
- tags: [Claude Code, Code Agent, AI编程, Anthropic, MCP]
- FAQ: Claude Code的架构核心是什么? / Code Agent怎么管理上下文? / MCP协议是什么?

约束：不修改核心内容，保持手机阅读友好，FAQ答案基于文章内容。" >> $LOG 2>&1
echo "DONE_BATCH_1" >> $LOG
date >> $LOG

# Batch 2: Articles 5-8
echo "--- Batch 2: ClickHouse, Databricks, dbt-Cube, DuckDB ---" >> $LOG
opencode run "请对 /root/workspace/hexo-blog/source/_posts/ 目录下以下4篇文章执行SEO优化。每篇文章做3件事：

1. 在front matter的tags行下面添加description字段
2. 将tags从'AI'改为3-5个语义化标签
3. 在'## 总结'段落之前插入FAQ段落（3个Q&A）

FAQ格式：**Q: 问题？** 换行 A: 回答。

文章1: ClickHouse-列式OLAP洞察.md
- description: ClickHouse靠列式存储、向量化执行和稀疏索引做到百毫秒级聚合查询，但多表JOIN是短板。含vs StarRocks选型建议。
- tags: [ClickHouse, OLAP, 列式存储, 数据库选型, StarRocks]
- FAQ: ClickHouse和StarRocks怎么选? / ClickHouse为什么JOIN慢? / ClickHouse适合什么场景?

文章2: Databricks-AI-BI洞察.md
- description: Databricks用AI/BI Genie加Unity Catalog加Delta Lake UniForm构成湖仓一体AI查询方案，开源语义层与Snowflake差异化对比。
- tags: [Databricks, AI/BI, 湖仓, Unity Catalog, Delta Lake]
- FAQ: Databricks AI/BI是什么? / Unity Catalog有什么用? / Delta Lake UniForm是什么?

文章3: dbt-Cube-开源语义层洞察.md
- description: dbt Semantic Layer和Cube是两个开源语义层方案，Cube在多仓库覆盖和架构独立性上更优。两者均支持MCP Server。
- tags: [dbt, Cube, 语义层, MCP, 数据建模]
- FAQ: dbt Semantic Layer是什么? / Cube和dbt怎么选? / 语义层支持MCP吗?

文章4: DuckDB-嵌入式分析数据库洞察.md
- description: DuckDB是分析界SQLite，无需独立服务进程直接嵌入应用运行，适合边缘设备轻量分析和AI查询场景。
- tags: [DuckDB, 嵌入式数据库, OLAP, SQLite, 边缘计算]
- FAQ: DuckDB是什么? / DuckDB和SQLite什么关系? / DuckDB适合什么场景?

约束：不修改核心内容，FAQ答案基于文章内容。" >> $LOG 2>&1
echo "DONE_BATCH_2" >> $LOG
date >> $LOG

# Batch 3: Articles 9-12
echo "--- Batch 3: Iceberg-Trino, Neo4j, SingleStore, Snowflake ---" >> $LOG
opencode run "请对 /root/workspace/hexo-blog/source/_posts/ 目录下以下4篇文章执行SEO优化。每篇文章做3件事：

1. 在front matter的tags行下面添加description字段
2. 将tags从'AI'改为3-5个语义化标签
3. 在'## 总结'段落之前插入FAQ段落（3个Q&A）

FAQ格式：**Q: 问题？** 换行 A: 回答。

文章1: Iceberg-Trino-开源湖仓查询洞察.md
- description: Iceberg加Trino加Polaris构成开源湖仓三件套，Trino查询比StarRocks慢约5倍，价值在标准对接而非替换执行引擎。
- tags: [Apache Iceberg, Trino, 湖仓, Polaris, 开源]
- FAQ: Trino为什么比StarRocks慢? / 开源湖仓三件套是什么? / Polaris是什么?

文章2: Neo4j-RelationalAI-知识图谱洞察.md
- description: 图查询在多跳遍历场景远胜SQL，Neo4j和RelationalAI代表两条不同技术路线。聚合分析应留在SQL引擎。
- tags: [Neo4j, 知识图谱, 图数据库, RelationalAI, Cypher]
- FAQ: 图查询比SQL好在哪? / Neo4j和RelationalAI怎么选? / 什么时候该用图数据库?

文章3: SingleStore-HTAP实时统一数据平台洞察.md
- description: SingleStore用一个引擎同时跑事务、分析和向量搜索，电信场景验证6-100倍查询加速。
- tags: [SingleStore, HTAP, 实时分析, 向量搜索, 数据库]
- FAQ: HTAP是什么? / SingleStore的统一引擎怎么工作? / 向量搜索和OLAP能合一吗?

文章4: Snowflake-AI查询与语义层洞察.md
- description: Snowflake用六阶段Agent流水线加原生语义层把text-to-SQL从51%提升到90%以上，语义模型驱动AI生成思路值得借鉴。
- tags: [Snowflake, AI查询, 语义层, Text-to-SQL, 数据仓库]
- FAQ: Snowflake的AI查询怎么工作? / text-to-SQL准确率怎么提升? / 语义层是什么?

约束：不修改核心内容，FAQ答案基于文章内容。" >> $LOG 2>&1
echo "DONE_BATCH_3" >> $LOG
date >> $LOG

# Batch 4: Articles 13-16
echo "--- Batch 4: 统一SQL, 全民分红, 终极社会主义AI猜想 ---" >> $LOG
opencode run "请对 /root/workspace/hexo-blog/source/_posts/ 目录下以下3篇文章执行SEO优化。每篇文章做3件事：

1. 在front matter的tags行下面添加description字段
2. 将tags改为3-5个语义化标签
3. 在'## 总结'或'## ✅ 总结'段落之前插入FAQ段落（3个Q&A）。注意：终极社会主义AI猜想.md没有总结段落，在文章末尾添加FAQ。

FAQ格式：**Q: 问题？** 换行 A: 回答。

文章1: 基于统一SQL的大模型友好查询洞察分享.md
- description: 跨库SQL适配有三条路线（联邦引擎、语义层、引擎统一），统一SQL加方言转换方案存在等价函数结构性风险。
- tags: [SQL, 联邦查询, 语义层, 方言转换, 多数据库]
- FAQ: 什么是SQL方言转换? / 联邦引擎和语义层有什么区别? / 多数据库怎么统一查询?

文章2: 终极社会主义AI猜想.md
- description: 社会主义的内在逻辑必然要求一个能进行全域智能调控的AI大脑作为技术基础。当前AI进化正使这一前提从理论走向现实。
- tags: [AI, 社会主义, 技术哲学, 生产力]
- FAQ: 什么是终极社会主义AI猜想? / AI能实现计划经济吗? / 生产力高度发达需要什么条件?

文章3: blog-article-universal-dividend.md (已有tags: [政治经济学, 数字经济, 全民分红]，只需添加description和FAQ)
- description: 中国内需困局症结在公有制分配端缺管道，全民分红是数字时代公有制必须补上的制度履约。
- FAQ: 全民分红的理论依据是什么? / 数字时代公有制怎么实现分配? / 全民分红和福利有什么区别?

约束：不修改核心内容，FAQ答案基于文章内容。" >> $LOG 2>&1
echo "DONE_BATCH_4" >> $LOG
date >> $LOG

echo "" >> $LOG
echo "=== Part A Complete ===" >> $LOG
