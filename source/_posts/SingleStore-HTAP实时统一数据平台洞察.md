---
title: SingleStore-HTAP实时统一数据平台洞察
date: 2026-07-16 11:00:00
tags: [SingleStore, HTAP, 统一数据平台, 向量搜索, StarRocks]
description: SingleStore用单一引擎跑事务加分析加向量搜索，电信场景替换Oracle后6-100倍加速。含vs StarRocks选型建议。
categories: 学习
---

💡 SingleStore 把事务、分析、向量搜索压到一个引擎里，电信场景替换 Oracle 后 6-100 倍加速。但"统一"的代价是放弃多引擎生态，联邦下推能力弱。

## 背景

HTAP（混合事务分析处理）是数据库领域的长期追求：一个引擎同时跑事务和分析，消除数据在系统间复制的延迟和成本。

SingleStore 是 DB-Engines 排名第 12 的分布式 SQL 数据库（2026 年 7 月，54 分），定位"实时统一数据平台"。在 Gartner 魔力象限中列为云 DBMS 远见者。

全球 Top 10 电信运营商中有 4 家使用 SingleStore 替换 Oracle Exadata。本文分析其核心能力与适用边界。

## 关键竞争力

SingleStore 的竞争力来自四个方面。

### 单引擎统一处理

一个引擎同时承载 OLTP（事务处理）和 OLAP（分析处理），数据无需在行存和列存之间复制。这是 HTAP 的核心承诺。

### 列存向量化执行

分析查询走列式存储 + 向量化执行 + 编码执行（延迟物化，只解码命中列）。性能在 ClickBench 等基准中接近纯 OLAP 引擎。

### MySQL 协议兼容

应用侧可沿用 MySQL 驱动，降低迁移成本。LLVM 代码生成把查询编译为本机码，启用函数内联、循环展开、向量化优化。

### 原生向量与混合搜索

原生 VECTOR 数据类型，同一列可创建多个不同类型索引。一条 SQL 内同时执行向量相似、BM25 全文匹配、JSON 提取、SQL 聚合与 JOIN，并可加权融合得分。

与现有架构的根本差异：SingleStore 是"一个引擎跑所有负载"，现有架构是"多个引擎各跑一类负载"。前者优势是无需 SQL 方言翻译、数据无需复制；后者优势是每个引擎在专长场景性能极致、可独立演进。

## Universal Storage 统一存储

### 列存为体、行存为缓存

列存数据按 segment 组织（每个 segment 存一行子集、按列分别压缩）。segment 元数据持久化在内存行存表内，可在内存中做 segment 消除（跳过不相关的数据块）。

最近写入先入内存行存，后台周期性将行存转为列存 segment，维持对数级有序结构。

### 五大事务能力

当前 Universal Storage 在列存上提供：hash 索引（可选唯一约束）、细粒度行列读取、行级锁、选择性过滤 JOIN、UPSERT（更新或插入）。

列存为默认表类型，压缩比可达 10:1 至 100:1。

与 StarRocks 对比：StarRocks 是纯列存 MPP 分析引擎，不承载事务。SingleStore 将事务与分析压到一个引擎内，去除了双系统间的数据同步与方言翻译。但代价是：纯分析场景未必胜过专用 OLAP，且生态规模低于 StarRocks。

## 原生向量与混合搜索

### VECTOR 类型与多索引

SingleStore 提供原生 VECTOR 数据类型，同一列可创建多个不同类型索引以适配不同场景。新插入向量立即可查，无异步索引构建延迟。

索引类型包括 HNSW（高召回、高维度）、IVF（低构建时间）、IVF_PQFS（低内存、快构建）；距离函数支持点积、欧几里得距离、余弦相似度，基于 Intel SIMD 指令加速。

### Top() 算子下推

VLDB 2024 论文引入 Top() 物理算子，将 top-k 向量搜索下推到表扫描，使向量搜索作为 filter 接入 SQL 执行流水线。

设计要点：每个 segment 独立索引，merger 构建跨 segment 大索引；根据用户需求自动选择索引算法与参数；向量索引与表存储一致，支持 ACID 事务。

### 混合搜索单 SQL 多路检索

一条 SQL 内同时执行向量相似、BM25 全文匹配、JSON 提取、SQL 聚合与 JOIN，并可加权融合得分：

```sql
SELECT title,
       DOT_PRODUCT(embedding, '[...]') AS v_score,
       MATCH(TABLE content) AGAINST('body:database') AS ft_score,
       (DOT_PRODUCT(embedding, '...') * 0.7 +
        MATCH(TABLE content) AGAINST('...') * 0.3) AS combined_score
FROM documents
WHERE category = 'Technical'
  AND combined_score > 0.5
ORDER BY combined_score DESC LIMIT 10;
...
```

在 45466 条电影记录、768 维向量的基准中，SingleStore 查询约 70ms，ClickHouse 冷缓存 2+ 秒。并发场景下 SingleStore 延迟方差更小，使用一半 vCPU。

### MongoDB 兼容 API

SingleStore Kai 提供 MongoDB 协议兼容 API，MongoDB 应用无需改代码即可切换，并获 100 倍分析加速。

与 StarRocks 向量能力对比：StarRocks 3.0+ 已具备原生向量类型、HNSW 索引、距离函数，并在阿里 EMR 上落地了"全文 + 标量 + 向量"三路融合检索，recall 较单路提升 30%、成本降 60%。两者能力已趋同，无需为向量能力引入 SingleStore。

## 与现有架构对比

| 维度 | SingleStore | 现有架构 |
|------|-------------|----------|
| 引擎数 | 单一 HTAP 引擎 | 多引擎分离 |
| 事务能力 | ACID（行存+列存统一） | GaussDB 承担 |
| 分析能力 | 列存向量化 + 编码执行 | StarRocks 向量化 + CBO |

| 维度 | SingleStore | 现有架构 |
|------|-------------|----------|
| 向量搜索 | 原生多索引 | StarRocks 3.0+ HNSW |
| 混合搜索 | 单 SQL 多路检索 | StarRocks 三路融合 |
| 联邦下推 | 弱（数据需入库） | 支持（实时下推多库） |

核心结论：

可借鉴：Universal Storage 三层架构与"行存为缓存"思路对 StarRocks 冷热分层有参考价值；"计算在数据平面内"理念对 AI 推理架构有启发。

不可借鉴：SingleStore 的单引擎路径要求放弃现有多引擎生态与运维投入，迁移成本高。现有架构已分摊负载，强行统一可能在专长场景性能回退。

根本差异：SingleStore 聚焦"数据已入库"后的统一处理；现有架构的核心差异化在于"数据分布在多库、实时下推"的联邦能力——这是 SingleStore 不擅长的领域。

## 电信案例详情

全球 Top 10 电信运营商替换 Oracle Exadata 的关键数据：

- 500+ 节点支撑 1.4 亿用户、1.8 万个 KPI
- 查询性能 6-100 倍提升、年节省 540 万美元
- 使用场景包括网络健康实时查询和基站故障工单系统
- 5G 带来数据量 20 倍增长，Oracle RAC 无法横向扩展是替换根本动机

## 这对读者意味着什么

如果你在用 Oracle Exadata 或类似的传统 HTAP 方案，SingleStore 是一个值得认真评估的替换选项。电信行业的案例证明了 6-100 倍加速和显著的成本节省，特别是当 5G 带来数据量爆发时，横向扩展能力比垂直扩展更重要。

但如果你已经用了 StarRocks + Druid + GaussDB 的多引擎架构，SingleStore 的价值不在于替换，而在于借鉴。它的 Universal Storage"行存为缓存"思路可以启发 StarRocks 的冷热分层设计，"计算在数据平面内"理念可以启发 AI 推理架构——把推理从跨网络调用变成数据平面内嵌。

从行业趋势看，HTAP 统一是一个观察方向而非短期行动。多引擎分离架构在专长场景的性能优势仍然显著，强行统一可能回退。核心判断依据是：你的架构差异化在于"联邦下推"还是"统一处理"？

## 参考链接

- [SingleStore官方文档](https://docs.singlestore.com/)
- [SingleStore Wikipedia](https://en.wikipedia.org/wiki/SingleStore)
- [HTAP Wikipedia](https://en.wikipedia.org/wiki/Hybrid_transactional/analytical_processing_(HTAP))
- [StarRocks官方文档](https://docs.starrocks.io/)
- [StarRocks GitHub](https://github.com/StarRocks/starrocks)

## ✅ 总结

- SingleStore 的 HTAP 统一在电信场景已验证（6-100 倍加速、540 万美元年节省），但该案例是替换 Oracle Exadata 这一传统架构，并非从 StarRocks/Druid 现代多引擎架构迁移。启示在于"HTAP 统一可行"，而非"应立即迁移"
- 三层存储架构和"计算在数据平面内"理念值得借鉴——前者对 StarRocks 冷热分层有参考价值，后者对 AI 推理架构有启发
- 现有多引擎分离架构当前仍适合多场景需求，HTAP 统一是观察方向而非短期行动。核心判断依据是：现有架构的联邦下推能力是 SingleStore 等单引擎方案不擅长的领域
