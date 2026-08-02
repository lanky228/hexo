---
title: Apache Iceberg 表格式——性能基准测试与架构优势洞察
date: 2026-07-22
tags: [AI, 数据湖, Iceberg]
categories: [学习]
description: TPC-DS 实测：Iceberg 公平对比仅快 4.7%，核心价值在架构治理而非裸性能
---

💡 Iceberg 公平对比下仅比裸 Parquet 快 4.7%，性能不是它的卖点。它真正的价值是用元数据文件替代 HMS，让表语义不绑定任何引擎，这是数据所有权层面的架构转移。

## 为什么关注 Iceberg

企业内部统一 SQL 查询服务面临数据湖化与开放表格式选型问题。Apache Iceberg 是业界增速最快的开放表格式，AWS、Snowflake、Google 集体站队，需要评估是否值得引入。

为验证 Iceberg 的性能价值，我们用 DuckDB 在本地跑了 TPC-DS（业界标准的数据仓库基准测试）benchmark，对比 Iceberg 表与裸 Parquet 表。

初步结果显示 Iceberg 在"分区版"场景下加速比高达 +45.6%。但进一步分析发现这个对比不对等，只有 Iceberg 用了分区。双方都分区后，加速比缩水到 +4.7%。

Netflix 开源 Iceberg 的动机，正是 Hive Metastore（Hive 的元数据服务，简称 HMS）在 PB 级数据上撑不住。这印证了 Iceberg 的核心价值不是性能，而是架构治理能力。

## Iceberg 关键竞争力

Iceberg 作为开放表格式（一种让多引擎都能读写同一份数据的表标准），竞争力体现在两个层面。

通用能力方面，Iceberg 是开放标准，同一份数据可被 Trino、Flink、Spark、DuckDB、Snowflake、BigQuery、Athena 等多引擎读写。底层基于 Parquet，兼容现有数据湖存储。元数据与数据同库存储，无需外部服务。

关键能力方面，Iceberg 不依赖外部元数据服务，元数据以文件形式存到对象存储，消除 HMS 单点故障与扩展瓶颈。每次写入生成 snapshot（快照，数据某一时刻的完整状态记录），可按 snapshot-id 或时间戳查询历史数据。支持 Schema 演进和 Hidden Partitioning（隐藏分区，用户只关心业务字段，分区路由交给引擎），增删改重命名字段不重写历史数据。用快照隔离 + 乐观并发 + 冲突重试实现 ACID 事务。提供 rewrite_data_files、rewrite_manifests、expire_snapshots 等标准维护操作。

## 软件架构

Iceberg 的核心设计：把表元数据以文件形式分层存储在对象存储中，与数据文件同库。

三层元数据文件结构：

- metadata.json（表级元数据）：存放表 schema、分区规则、属性，包含当前快照指针和历史快照列表，是 Time Travel 的基础
- manifest list（快照清单）：每个快照对应一个，指向多个 manifest
- manifest（数据文件清单）：记录每个数据文件路径、文件级统计（min/max/记录数）和列级统计，引擎据此做分区裁剪和谓词下推（把过滤条件推到存储层执行）

引擎只需依次读取这三层文件，就能获得完整表语义，无需任何常驻元数据服务。

HMS 是常驻 RPC 服务，元数据存于关系数据库，引擎通过 Thrift RPC 获取表元数据。Iceberg 的元数据就是文件，引擎直接读对象存储。这一差异消除了 HMS 的三大顽疾：单点故障、RPC 瓶颈、元数据与数据不一致。

分区规则变更后，老数据按旧规则读、新数据按新规则写，多套规则共存，这是分区演进的技术基础。写入采用乐观并发，提交时检查 metadata.json 是否被其他写入修改，冲突则重试。

## 性能实测：四个场景对比

### 测试环境与方法

测试环境：DuckDB 1.x + Iceberg 1.11.0 + Java 17 + 向量化全开 + 10g driver。

测试方法：TPC-DS benchmark，对比 Iceberg 表与裸 Parquet 表在相同查询集上的执行耗时，88 个有效查询。分别在 SF1/SF5（SF 即 Scale Factor，数据规模系数）、分区/未分区、公平/不对等对比等多个场景下测试。

### 测试结果汇总

| 测试场景 | Iceberg 胜 | 总加速比 | 说明 |
|---------|-----------|---------|------|
| SF5 未分区 | 61/88 (69%) | +0.2% | Raw 胜 27；无分区时无优势 |
| SF5 公平对比 | 71/88 (81%) | +4.7% | 双方均开分区 + DPP |
| SF5 分区版（仅 Iceberg 分区） | 83/88 (94%) | +45.6% | 不对等对比 |
| SF1 分区版 | 68/88 (77%) | +18.0% | 数据量小时优势更小 |

注意："分区版"场景仅 Iceberg 分区、Raw 不分区，本质是分区优势而非表格式优势，不能据此判断 Iceberg 更快。

### SF5 公平对比详细分析

这是本报告最核心的实测结论，双方都分区，88 个有效查询。

总体：Raw 总耗时 770.8s，Iceberg 734.3s，加速 +4.7%。

Iceberg 大幅领先 TOP5：

| 查询 | 加速比 |
|------|--------|
| Q5 | +52.6% |
| Q52 | +51.7% |
| Q44 | +43.0% |
| Q8 | +43.6% |
| Q65 | +38.3% |

Raw 反超 TOP5：

| 查询 | 加速比 |
|------|--------|
| Q69 | -112.9% |
| Q10 | -89.3% |
| Q35 | -86.9% |
| Q7 | -68.9% |
| Q74 | -61.8% |

反超原因：Iceberg 输的查询集中在多表 JOIN（多表关联）场景。Iceberg 底层也是 Parquet，多了元数据层反而有额外开销，在 JOIN 密集场景下被放大。

### 关键结论

公平对比下 Iceberg 仅快 4.7%，性能不是核心卖点。双方都分区 + DPP（Dynamic Partition Pruning，动态分区裁剪）的对等条件下，Iceberg 胜率 81% 但总加速比仅 +4.7%，远非数量级差异。

+45.6% 的大优势主要来自分区 vs 不分区的不对等。不能把分区带来的收益归因于 Iceberg。

Iceberg 多了元数据层，反而有额外开销。多表 JOIN 场景反而更慢（Q69 -112.9%、Q10 -89.3%），说明元数据层在复杂查询中有性能代价。

优势随数据量变化。SF1 分区版 +18.0% 到 SF5 公平对比 +4.7%。数据量小时 Iceberg 优势更小，元数据开销在小数据集上占比更高。

## 架构优势解析

性能虽非核心卖点，但 Iceberg 在架构治理能力上全面超越裸 Parquet。

### 不依赖外部元数据服务

HMS 的痛点在于单点故障（HMS 宕机导致全表不可访问）、扩展瓶颈（万级分区时 RPC 调用成为瓶颈）、元数据与数据不一致、并发无事务。

Iceberg 的元数据以三层文件存到对象存储，与数据同库。引擎只需读文件即可获得完整表语义，无需任何常驻服务。Netflix 开源动机正是 HMS 在 PB 级撑不住。AWS S3 Tables 把 Iceberg 作为一等公民，Snowflake 捐 Polaris Catalog 给 ASF。

### Time Travel（历史时间查询）

每次写入生成快照，查询可指定 snapshot-id 或时间戳。引擎原生支持（Spark/Trino/Flink SQL 语法）。用途包括可重现报表、审计合规、故障排查、ML 训练复现、A/B 实验。

裸 Parquet + HMS 几乎无法做 Time Travel，数据覆盖即丢失历史。

### Schema 演进与隐藏分区

Schema 演进支持 add/drop/rename/reorder，不重写历史数据。通过 column id 映射实现，字段重命名不影响历史数据读取。

Hidden Partitioning 让用户按业务字段过滤（如 `WHERE event_date = '2026-07-01'`），引擎自动路由到对应分区。分区规则变更后，老数据按旧规则读、新数据按新规则写，迁移无感。对比 HMS：改分区需重写全表，迁移成本极高。

### 数据维护

| 维护操作 | 作用 |
|---------|------|
| rewrite_data_files | 合并小文件（binpack/sort/z-order） |
| rewrite_manifests | 整理 manifest 加速查询计划 |
| expire_snapshots | 回收历史快照，释放存储 |
| remove_orphan_files | 清理孤儿文件 |

这些维护操作均为标准 procedure（标准存储过程），引擎直接调用，无需自己写脚本。裸 Parquet 的小文件治理需自行编写脚本，运维成本高。

### Parquet vs Iceberg 能力对比

| 能力 | 裸 Parquet | Iceberg |
|------|-----------|---------|
| ACID 事务 | 无 | 快照隔离 |
| 并发写入 | 需自己加锁 | 乐观并发 + 冲突重试 |
| Time travel | 覆盖就没了 | 原生 |
| Schema 演进 | 仅靠约定 | metadata 驱动 |
| 分区演进 | 改分区重写全表 | 新旧规则共存 |
| 小文件治理 | 自己写脚本 | 标准 procedure |
| 跨引擎表语义 | 各自约定 | 规范统一 |
| 增量消费 | 自己扫描目录 | snapshot 增量 |

Iceberg 在 Parquet 之上增加了一层元数据管理，代价是少量性能开销（公平对比仅 +4.7%，JOIN 场景甚至更慢），换来的是 ACID、Time Travel、Schema/分区演进、小文件治理、跨引擎表语义统一等完整的数据管理能力。

裸 Parquet 是存储格式，Iceberg 是表格式，两者不在同一层级。

### 业界采纳

Netflix 开源 Iceberg 的动机是 HMS 在 PB 级撑不住。AWS S3 Tables 将 Iceberg 作为一等公民。Snowflake 捐 Polaris Catalog 给 ASF，强调"数据属于客户"。2024 年 Tabular 被 Databricks 收购后，AWS/Snowflake/Google 集体站队 Iceberg。Apple、Stripe、字节、腾讯等公开分享 hidden partitioning + compaction 为运维省心关键。

## 三大表格式对比

| 维度 | Iceberg | Delta Lake | Hudi |
|------|---------|------------|------|
| 主导方 | Apache（原 Netflix），中立 | Databricks 主导 | Apache（原 Uber） |
| 核心定位 | 通用开放表格式，引擎无关 | Spark 生态一等公民 | 流式/upsert 优先 |
| 引擎支持 | 全覆盖 | Spark 最完整 | Spark/Flink 为主 |
| Time travel | 统一清晰 | 清晰，同档 | COW/MOR 语义不一致 |
| Schema/分区演进 | 业界公认最干净 | 良好 | 受限于 key 模型 |
| 社区热度 | 增速最快 | 体量最大，绑定 Databricks | 增量场景稳固 |

注：COW/MOR 指 Copy on Write（写时复制）和 Merge on Read（读时合并），是两种不同的数据更新策略，Hudi 在两种模式下 Time Travel 语义不一致。

选型建议：Iceberg 适合多引擎多云场景，开放中立性最优，引擎支持最广。Delta Lake 适合以 Spark/Databricks 为核心生态，但开放性偏弱。Hudi 在流式 upsert 场景有优势，但 COW/MOR 语义不一致增加认知负担。

若要引入开放表格式，Iceberg 是首选，中立性和引擎覆盖面最契合多引擎架构。

## Iceberg 与 StarRocks 本地表对比

引入 Iceberg 意味着需要在 StarRocks 本地表（数据存在 StarRocks 内部的表）与 Iceberg 外表（数据存在 Iceberg、由 StarRocks 查询的表）之间做取舍。

| 维度 | StarRocks 本地表 | Iceberg 外表 |
|------|-----------------|--------------|
| 存储格式 | 自研列式（RLE/字典/前缀编码） | Parquet + Iceberg 元数据层 |
| 查询性能 | 最优（向量化 + CBO + 本地缓存） | 有额外开销（元数据解析 + 外表访问） |
| ACID 事务 | 部分支持（主键表） | 快照隔离 |
| Time Travel | 原生不支持 | 原生 |
| Schema/分区演进 | 受限（改分区需重建） | 无感演进 |
| 跨引擎表语义 | StarRocks 私有 | 多引擎统一 |
| 数据可移植性 | 锁定 StarRocks | 引擎无关 |

注：CBO 指 Cost-Based Optimizer，基于代价的查询优化器。

对比关键结论：

性能上 StarRocks 本地表优于 Iceberg 外表。Iceberg 相比裸 Parquet 仅 +4.7%（公平对比），而 StarRocks 本地表在向量化执行、CBO 优化、本地缓存加持下，查询性能通常优于外表扫描。JOIN 密集场景尤为明显。

架构治理上 Iceberg 外表全面领先。Time Travel、Schema/分区演进、ACID、跨引擎表语义统一是 StarRocks 本地表不具备或不完整的能力。这些能力解决的是数据能不能用得舒服的问题。

建议分层存储而非二选一。热数据/交互分析走 StarRocks 本地表保性能；冷数据/治理数据/跨引擎共享数据走 Iceberg 外表保开放性。StarRocks 已支持 Iceberg 外表查询，可实现混合架构。

不应期待 Iceberg 带来性能提升。实测数据明确表明，Iceberg 的价值在架构治理而非裸性能。引入依据应是"需要 Time Travel / Schema 演进 / 跨引擎表语义 / 消除 HMS 依赖"，而非"查询更快"。

## 这对读者意味着什么

如果你正在评估数据平台技术选型，这篇文章最重要的信号是：不要被"+45.6%"这种数字误导。很多技术方案的 benchmark 数据来自不对等对比，把分区的收益伪装成格式的收益。评估表格式时，一定要确认对比是否公平，双方是否都启用了分区和裁剪。这个方法论适用于任何存储格式选型。

对数据平台架构师来说，Iceberg 的价值判断已经从"能不能更快"转向"能不能更开放"。封闭仓库的本质是数据人质，你的数据在我的系统里，你走不了。Iceberg 打破这个锁定靠的不是性能优势，而是把表语义从引擎私有变成开放标准。当你评估是否引入 Iceberg 时，真正的问题不是"它能快多少"，而是"我的数据需不需要跨引擎、跨云、跨团队共享"。如果答案是肯定的，Iceberg 目前是最大公约数。

从行业格局看，2024 年 Tabular 被 Databricks 收购后，AWS/Snowflake/Google 集体站队 Iceberg，这不是偶然。云厂商发现封闭存储的锁定溢价正在被开放格式侵蚀，与其抵抗不如拥抱。对用户来说，选择 Iceberg 的生态风险在降低，因为最大的几家云厂商都在押注它。

## 参考链接

- [Apache Iceberg官方文档](https://iceberg.apache.org/docs/latest/)
- [Iceberg表格式规范](https://iceberg.apache.org/spec/)
- [Apache Iceberg Wikipedia](https://en.wikipedia.org/wiki/Apache_Iceberg)
- [Trino官方文档](https://trino.io/docs/current/)
- [Trino Wikipedia](https://en.wikipedia.org/wiki/Trino_(SQL_query_engine))
- [Presto到Trino的历史](https://trino.io/blog/2020/12/27/announcing-trino.html)
- [DuckDB官方文档](https://duckdb.org/docs/)
- [DuckDB Wikipedia](https://en.wikipedia.org/wiki/DuckDB)

## 常见问题

Q: Iceberg 比 Parquet 快吗？

公平对比下（双方都分区），Iceberg 仅快 4.7%。所谓"+45.6%"的结论来自不对等对比，只有 Iceberg 用了分区。Iceberg 底层也是 Parquet，多了元数据层，在多表 JOIN 场景反而更慢。

Q: 既然性能没优势，为什么还要用 Iceberg？

性能从来不是 Iceberg 的卖点。它的价值在于不依赖外部元数据服务（消除 HMS 单点故障）、Time Travel（历史数据可追溯）、Schema/分区无感演进、ACID 事务、跨引擎表语义统一。这些解决的是数据能不能用得舒服的问题，不是跑得多快。

Q: Iceberg、Delta Lake、Hudi 怎么选？

多引擎多云场景选 Iceberg（中立性最优，引擎覆盖最广）；以 Spark/Databricks 为核心选 Delta；流式 upsert 场景选 Hudi。若只引入一种，Iceberg 是最大公约数。

Q: 已经用了 StarRocks 本地表，还需要 Iceberg 吗？

建议分层存储而非二选一。热数据/交互分析走 StarRocks 本地表保性能，冷数据/治理数据/跨引擎共享数据走 Iceberg 外表保开放性。两者解决不同问题。

## ✅ 总结

- Iceberg 性能不比裸 Parquet 快多少。公平对比仅 +4.7%，+45.6% 的大优势来自分区 vs 不分区的不对等。不应以性能为由引入 Iceberg。
- 不依赖元数据服务是架构核心优势。消除 HMS 三大顽疾（单点故障、扩展瓶颈、元数据不一致）。Netflix 开源动机正是 HMS 在 PB 级撑不住。
- Time Travel、Schema/分区演进、ACID 解决的是能不能用得舒服的问题，不是跑得多快。这些能力让数据治理从自己写脚本升级为标准 procedure，裸 Parquet 无法企及。
- Iceberg 开放中立性优于 Delta（偏 Databricks）和 Hudi（偏流式），是多引擎多云的最大公约数。引擎覆盖最广，最契合多引擎架构。
- 若引入开放表格式，Iceberg 是首选，但不期待性能提升，着眼架构治理。建议分层存储：热数据走 StarRocks 本地表保性能，冷数据/治理数据/跨引擎共享数据走 Iceberg 外表保开放性。
