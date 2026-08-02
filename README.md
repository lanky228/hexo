# Hexo 博客

> GitHub Pages 博客 — 技术文章与科普内容

## 项目信息

- **源码仓库**: `lanky228/hexo` (GitHub, `master` 分支)
- **线上地址**: `lanky228.github.io`
- **文章目录**: `source/_posts/`
- **主题**: 内置主题

## 文章列表

现有29篇已发布文章，涵盖：
- AI编程实践、验证方法论
- 数据库查询引擎（ClickHouse/DuckDB/Iceberg/Trino等）
- 语义层与AI查询（Snowflake/Databricks/BigQuery/dbt）
- 统一SQL框架

## 快速操作

```bash
# 发布新文章
cp article.md source/_posts/
git add . && git commit -m "publish: <title>" && git push origin master

# 构建部署
npx hexo clean && npx hexo generate && npx hexo deploy

# ⚠️ 部署前需临时修改 _config.yml deploy段为HTTPS+token格式
# ⚠️ 部署后必须恢复原始 _config.yml
```

## AI约束

操作本仓库前必读 `AGENTS.md` — 包含手机阅读规范、发布流程、博客重打磨约束。
