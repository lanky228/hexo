---
title: Apache Iceberg 表格式——性能基准测试与架构优势洞察
date: 2026-07-22
tags: [AI, 数据湖, Iceberg]
categories: [学习]
description: TPC-DS 实测：Iceberg 公平对比仅快 4.7%，核心价值在架构治理而非裸性能
---

💡 **一句话总结**

本地 DuckDB TPC-DS 实测发现：公平对比下 Iceberg 仅比裸 Parquet 快 4.7%，性能并非它的核心卖点。它真正的价值在不依赖元数据服务、Time Travel（历史时间查询）、Schema/分区演进、ACID 事务，以及跨引擎表语义统一等架构治理能力。

---

## 为什么关注 Iceberg

企业内部统一 SQL 查询服务面临数据湖化与开放表格式选型问题。Apache Iceberg 是业界增速最快的开放表格式，AWS、Snowflake、Google 集体站队，需要评估是否值得引入。

为验证 Iceberg 的性能价值，我们用 DuckDB 在本地跑了 TPC-DS（业界标准的数据仓库基准测试）benchmark，对比 Iceberg 表与裸 Parquet 表。

初步结果显示 Iceberg 在"分区版"场景下加速比高达 +45.6%。但进一步分析发现这个对比不对等——只有 Iceberg 用了分区。双方都分区后，加速比缩水到 +4.7%。

业界调研也印证：Iceberg 的核心价值不是性能，而是架构治理能力。Netflix 开源 Iceberg 的动机，正是 Hive Metastore（Hive 的元数据服务，简称 HMS）在 PB 级数据上撑不住。

---

## Iceberg 关键竞争力

Iceberg 作为开放表格式（一种让多引擎都能读写同一份数据的表标准），竞争力体现在五个维度。

📌 **通用能力**

- 开放标准，引擎无关：同一份数据可被 Trino、Flink、Spark、DuckDB、Snowflake、BigQuery、Athena 等多引擎读写
- 底层基于 Parquet，兼容现有数据湖存储
- 元数据与数据同库存储，无需外部服务

📌 **关键能力**

- **不依赖外部元数据服务**：元数据以文件形式存到对象存储，消除 HMS 单点故障与扩展瓶颈
- **Time Travel**：每次写入生成 snapshot（快照，数据某一时刻的完整状态记录），可按 snapshot-id 或时间戳查询历史数据
- **Schema 演进 / Hidden Partitioning（隐藏分区，用户只关心业务字段，分区路由交给引擎）**：增删改重命名字段不重写历史数据；分区规则可无感变更
- **ACID 事务**：ACID 即数据库事务的四大保障（原子性、一致性、隔离性、持久性），Iceberg 用快照隔离 + 乐观并发 + 冲突重试实现
- **数据维护**：提供 rewrite_data_files、rewrite_manifests、expire_snapshots 等标准维护操作

---

## 软件架构

Iceberg 的核心设计：把表元数据以文件形式分层存储在对象存储中，与数据文件同库。

📌 **三层元数据文件结构**

- **metadata.json（表级元数据）**：存放表 schema、分区规则、属性；包含当前快照指针和历史快照列表，是 Time Travel 的基础
- **manifest list（快照清单）**：每个快照对应一个，指向多个 manifest
- **manifest（数据文件清单）**：记录每个数据文件路径、文件级统计（min/max/记录数）和列级统计，引擎据此做分区裁剪和谓词下推（把过滤条件推到存储层执行）

引擎只需依次读取这三层文件，就能获得完整表语义，无需任何常驻元数据服务。

📌 **与 HMS 的根本差异**

HMS 是常驻 RPC 服务，元数据存于关系数据库，引擎通过 Thrift RPC 获取表元数据。Iceberg 的元数据就是文件，引擎直接读对象存储。

这一差异消除了 HMS 的三大顽疾：单点故障、RPC 瓶颈、元数据与数据不一致。

其他架构特征：分区规则变更后，老数据按旧规则读、新数据按新规则写，多套规则共存——这是分区演进的技术基础。写入采用乐观并发，提交时检查 metadata.json 是否被其他写入修改，冲突则重试。

---

## 性能实测：四个场景对比

### 测试环境与方法

**测试环境**：DuckDB 1.x + Iceberg 1.11.0 + Java 17 + 向量化全开 + 10g driver

**测试方法**：TPC-DS benchmark，对比 Iceberg 表与裸 Parquet 表在相同查询集上的执行耗时，88 个有效查询。分别在 SF1/SF5（SF 即 Scale Factor，数据规模系数）、分区/未分区、公平/不对等对比等多个场景下测试。

### 测试结果汇总

| 测试场景 | Iceberg 胜 | 总加速比 | 说明 |
|---------|-----------|---------|------|
| SF5 未分区 | 61/88 (69%) | +0.2% | Raw 胜 27；无分区时 Iceberg 无优势 |
| SF5 公平对比 | 71/88 (81%) | +4.7% | Raw 胜 17；双方均开分区 + DPP |
| SF5 分区版（仅 Iceberg 分区） | 83/88 (94%) | +45.6% | Raw 胜 5；不对等对比 |
| SF1 分区版 | 68/88 (77%) | +18.0% | Raw 胜 20；数据量小时优势更小 |

⚠️ **注意**："分区版"场景仅 Iceberg 分区、Raw 不分区，本质是分区优势而非表格式优势，不能据此判断 Iceberg 更快。

### SF5 公平对比详细分析

这是本报告最核心的实测结论——双方都分区，88 个有效查询。

**总体**：Raw 总耗时 770.8s，Iceberg 734.3s，加速 +4.7%。

**Iceberg 大幅领先 TOP5：**

| 查询 | 加速比 |
|------|--------|
| Q5 | +52.6% |
| Q52 | +51.7% |
| Q44 | +43.0% |
| Q8 | +43.6% |
| Q65 | +38.3% |

**Raw 反超 TOP5：**

| 查询 | 加速比 |
|------|--------|
| Q69 | -112.9% |
| Q10 | -89.3% |
| Q35 | -86.9% |
| Q7 | -68.9% |
| Q74 | -61.8% |

**反超原因**：Iceberg 输的查询集中在多表 JOIN（多表关联）场景。Iceberg 底层也是 Parquet，多了元数据层反而有额外开销，在 JOIN 密集场景下被放大。

### 关键结论

1. **公平对比下 Iceberg 仅快 4.7%，性能不是核心卖点。** 双方都分区 + DPP（Dynamic Partition Pruning，动态分区裁剪）的对等条件下，Iceberg 胜率 81% 但总加速比仅 +4.7%，远非数量级差异。

2. **+45.6% 的大优势主要来自分区 vs 不分区的不对等。** 不能把分区带来的收益归因于 Iceberg。

3. **Iceberg 多了元数据层，反而有额外开销。** 多表 JOIN 场景反而更慢（Q69 -112.9%、Q10 -89.3%），说明元数据层在复杂查询中有性能代价。

4. **优势随数据量变化。** SF1 分区版 +18.0% → SF5 公平对比 +4.7%。数据量小时 Iceberg 优势更小，元数据开销在小数据集上占比更高。

---

## 架构优势解析

性能虽非核心卖点，但 Iceberg 在架构治理能力上全面超越裸 Parquet。

### 不依赖外部元数据服务

📌 **HMS 痛点**

- 单点故障：HMS 宕机导致全表不可访问
- 扩展瓶颈：万级分区时 RPC 调用成为瓶颈
- 元数据与数据不一致：HMS 元数据与实际数据文件可能脱节
- 并发无事务：多写入并发时无 ACID 保证

📌 **Iceberg 方案**

- 元数据以三层文件存到对象存储，与数据同库
- 引擎只需读文件即可获得完整表语义，无需任何常驻服务
- Netflix 开源动机正是 HMS 在 PB 级撑不住
- AWS S3 Tables 把 Iceberg 作为一等公民，Snowflake 捐 Polaris Catalog 给 ASF

### Time Travel（历史时间查询）

- 每次写入生成快照，查询可指定 snapshot-id 或时间戳
- 引擎原生支持（Spark/Trino/Flink SQL 语法）
- 用途：可重现报表、审计合规、故障排查、ML 训练复现、A/B 实验
- 裸 Parquet + HMS 几乎无法做 Time Travel——数据覆盖即丢失历史

### Schema 演进与隐藏分区

📌 **Schema 演进（表结构演进）**

- 支持 add/drop/rename/reorder，不重写历史数据
- 通过 column id 映射实现，字段重命名不影响历史数据读取

📌 **Hidden Partitioning（隐藏分区）**

- 用户按业务字段过滤（如 `WHERE event_date = '2026-07-01'`），引擎自动路由到对应分区
- 分区规则变更后，老数据按旧规则读、新数据按新规则写，迁移无感
- 对比 HMS：改分区需重写全表，迁移成本极高

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
| ACID 事务 | ❌ 无 | ✅ 快照隔离 |
| 并发写入 | ❌ 需自己加锁 | ✅ 乐观并发 + 冲突重试 |
| Time travel | ❌ 覆盖就没了 | ✅ 原生 |
| Schema 演进 | ⚠️ 仅靠约定 | ✅ metadata 驱动 |
| 分区演进 | ❌ 改分区重写全表 | ✅ 新旧规则共存 |
| 小文件治理 | ❌ 自己写脚本 | ✅ 标准 procedure |
| 跨引擎表语义 | ❌ 各自约定 | ✅ 规范统一 |
| 增量消费 | ❌ 自己扫描目录 | ✅ snapshot 增量 |

💡 **核心差异**：Iceberg 在 Parquet 之上增加了一层元数据管理，代价是少量性能开销（公平对比仅 +4.7%，JOIN 场景甚至更慢），换来的是 ACID、Time Travel、Schema/分区演进、小文件治理、跨引擎表语义统一等完整的数据管理能力。

裸 Parquet 是"存储格式"，Iceberg 是"表格式"——两者不在同一层级。

### 业界采纳

- **Netflix**：开源 Iceberg 的动机是 HMS 在 PB 级撑不住
- **AWS**：S3 Tables 将 Iceberg 作为一等公民
- **Snowflake**：捐 Polaris Catalog 给 ASF，强调"数据属于客户"
- **2024 Tabular 被 Databricks 收购后**，AWS/Snowflake/Google 集体站队 Iceberg
- **Apple、Stripe、字节、腾讯**等公开分享 hidden partitioning + compaction 为运维省心关键

---

## 三大表格式对比

| 维度 | Iceberg | Delta Lake | Hudi |
|------|---------|------------|------|
| 主导方 | Apache（原 Netflix），中立 | Databricks 主导 | Apache（原 Uber） |
| 核心定位 | 通用开放表格式，引擎无关 | Spark 生态一等公民 | 流式/upsert 优先 |
| 引擎支持 | 全覆盖 | Spark 最完整，其他逐步提升 | Spark/Flink 为主 |
| Time travel | 统一清晰 | 清晰，同档 | COW/MOR 语义不一致 |
| Schema/分区演进 | 业界公认最干净 | 良好 | 受限于 key 模型 |
| 社区热度 | 增速最快，云厂商集体站队 | 体量最大，绑定 Databricks | 增量场景稳固，新增放缓 |

> 注：COW/MOR 指 Copy on Write（写时复制）和 Merge on Read（读时合并），是两种不同的数据更新策略，Hudi 在两种模式下 Time Travel 语义不一致。

📌 **选型建议**

- **Iceberg**：多引擎多云场景的最大公约数，开放中立性最优，引擎支持最广
- **Delta Lake**：若以 Spark/Databricks 为核心生态，Delta 是一等公民，但开放性偏弱
- **Hudi**：流式 upsert 场景有优势，但新增场景放缓，COW/MOR 语义不一致增加认知负担

若要引入开放表格式，**Iceberg 是首选**——中立性和引擎覆盖面最契合多引擎架构。

---

## Iceberg 与 StarRocks 本地表对比

引入 Iceberg 意味着需要在 StarRocks 本地表（数据存在 StarRocks 内部的表）与 Iceberg 外表（数据存在 Iceberg、由 StarRocks 查询的表）之间做取舍。

| 维度 | StarRocks 本地表 | Iceberg 外表 |
|------|-----------------|--------------|
| 存储格式 | 自研列式（RLE/字典/前缀编码） | Parquet + Iceberg 元数据层 |
| 查询性能 | 最优（向量化 + CBO + 本地缓存） | 有额外开销（元数据解析 + 外表访问） |
| ACID 事务 | ⚠️ 部分支持（主键表） | ✅ 快照隔离 |
| Time Travel | ❌ 原生不支持 | ✅ 原生 |
| Schema/分区演进 | ⚠️ 受限（改分区需重建） | ✅ 无感演进 |
| 跨引擎表语义 | ❌ StarRocks 私有 | ✅ 多引擎统一 |
| 小文件治理 | ⚠️ 内部自动 Compaction | ✅ 标准 procedure |
| 数据可移植性 | ❌ 锁定 StarRocks | ✅ 引擎无关 |

> 注：CBO 指 Cost-Based Optimizer，基于代价的查询优化器。

📌 **对比关键结论**

1. **性能上 StarRocks 本地表优于 Iceberg 外表。** Iceberg 相比裸 Parquet 仅 +4.7%（公平对比），而 StarRocks 本地表在向量化执行、CBO 优化、本地缓存加持下，查询性能通常优于外表扫描。JOIN 密集场景尤为明显。

2. **架构治理上 Iceberg 外表全面领先。** Time Travel、Schema/分区演进、ACID、跨引擎表语义统一是 StarRocks 本地表不具备或不完整的能力。这些能力解决的是"数据能不能用得舒服"的问题。

3. **建议分层存储而非二选一。** 热数据/交互分析走 StarRocks 本地表保性能；冷数据/治理数据/跨引擎共享数据走 Iceberg 外表保开放性。StarRocks 已支持 Iceberg 外表查询，可实现混合架构。

4. **不应期待 Iceberg 带来性能提升。** 实测数据明确表明，Iceberg 的价值在架构治理而非裸性能。引入依据应是"需要 Time Travel / Schema 演进 / 跨引擎表语义 / 消除 HMS 依赖"，而非"查询更快"。

---

## ✅ 总结

1. **Iceberg 性能不比裸 Parquet 快多少。** 公平对比仅 +4.7%，+45.6% 的大优势来自分区 vs 不分区的不对等。不应以性能为由引入 Iceberg。

2. **不依赖元数据服务是架构核心优势。** 消除 HMS 三大顽疾（单点故障、扩展瓶颈、元数据不一致）。Netflix 开源动机正是 HMS 在 PB 级撑不住。

3. **Time Travel、Schema/分区演进、ACID 解决的是"能不能用得舒服"的问题**，不是"跑得多快"。这些能力让数据治理从"自己写脚本"升级为"标准 procedure"，裸 Parquet 无法企及。

4. **Iceberg 开放中立性优于 Delta（偏 Databricks）和 Hudi（偏流式）**，是多引擎多云的最大公约数。引擎覆盖最广，最契合多引擎架构。

5. **若引入开放表格式，Iceberg 是首选**，但不期待性能提升，着眼架构治理。建议分层存储：热数据走 StarRocks 本地表保性能，冷数据/治理数据/跨引擎共享数据走 Iceberg 外表保开放性。

---

## 参考资料

- [Apache Iceberg 官方文档](https://iceberg.apache.org/)
- [Netflix Iceberg TechBlog](https://netflixtechblog.com/)
- [AWS S3 Tables](https://aws.amazon.com/s3/features/tables/)
- [Apache Polaris (TLP)](https://github.com/apache/polaris/)
- [DuckDB Iceberg Extension](https://duckdb.org/docs/extensions/iceberg)
- [Tabular (acquired by Databricks)](https://tabular.io/)
