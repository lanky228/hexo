#!/bin/bash
# Blog GEO+SEO Content Optimization Runner
# Sequentially processes all blog posts for SEO/GEO optimization

cd /root/workspace/hexo-blog

LOG=/root/workspace/hexo-blog/run-geo-seo.log
echo "=== Blog GEO+SEO Content Optimization Started ===" > $LOG
date >> $LOG

# Phase 2 Part A: Optimize 15 technical articles
echo "" >> $LOG
echo "--- Part A: Optimizing 15 technical articles ---" >> $LOG

opencode run "请阅读 /root/workspace/blog-geo-seo-content-spec.md 中的优化规范，然后对 /root/workspace/hexo-blog/source/_posts/ 目录下的15篇2026年技术文章执行以下优化：

1. 添加 description 到 front matter（按规范中每篇文章的 description）
2. 精细化 tags（将 tags: AI 替换为规范中指定的3-5个语义化标签）
3. 在文章的 ✅总结 段落之前添加 FAQ 段落（按规范中的FAQ方向，3-5个Q&A）
4. 补充外链（在相关段落自然嵌入5-10个到官方文档/论文的链接）
5. 添加内部链接（2-3个到博客其他文章的相对路径链接）

15篇文章列表：
1. AI编程实践洞察与工程原则.md
2. Apache-Iceberg表格式性能与架构洞察.md
3. Apache-Pinot-实时OLAP洞察.md
4. BigQuery-Looker-Gemini洞察.md
5. Claude-Code-开源代码与Code-Agent技术洞察.md
6. ClickHouse-列式OLAP洞察.md
7. Databricks-AI-BI洞察.md
8. dbt-Cube-开源语义层洞察.md
9. DuckDB-嵌入式分析数据库洞察.md
10. Iceberg-Trino-开源湖仓查询洞察.md
11. Neo4j-RelationalAI-知识图谱洞察.md
12. SingleStore-HTAP实时统一数据平台洞察.md
13. Snowflake-AI查询与语义层洞察.md
14. 基于统一SQL的大模型友好查询洞察分享.md
15. blog-article-universal-dividend.md

额外: 终极社会主义AI猜想.md 也需要同样优化。

重要约束：
- 不要修改文章核心内容和数据
- 保持手机阅读友好（段落≤4行）
- FAQ格式: **Q: 问题** 换行 A: 回答
- 内链用相对路径: [标题](/2026/07/16/slug/)
- 外链必须是真实官方URL
- description在160字以内" >> $LOG 2>&1

echo "DONE_PART_A" >> $LOG
date >> $LOG

# Phase 2 Part B: Add noindex to 11 old articles
echo "" >> $LOG
echo "--- Part B: Adding noindex to old articles ---" >> $LOG

opencode run "对 /root/workspace/hexo-blog/source/_posts/ 目录下的2020年旧文章添加 noindex: true 到 front matter。

需要处理的文章（在 front matter 的 --- 块内添加 noindex: true 行）：
1. 中国银行原油宝事件.md
2. 地下城堡2-暗影刺客赫芬琳.md
3. 孙杨抗检事件.md
4. 宇称不守恒.md
5. 广义相对论.md
6. 狭义相对论.md
7. 量子力学.md
8. 读书笔记-Web安全深度解析.md
9. 读书笔记-开发者测试.md
10. 读书笔记-异常处理的设计与重构.md

只添加 noindex: true，不要修改其他内容。" >> $LOG 2>&1

echo "DONE_PART_B" >> $LOG
date >> $LOG

echo "" >> $LOG
echo "=== All content optimization complete ===" >> $LOG
