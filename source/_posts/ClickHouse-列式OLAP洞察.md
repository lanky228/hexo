---
title: ClickHouse列式OLAP数据库洞察——极致查询性能背后的技术架构与StarRocks竞品对比
date: 2026-07-16 09:00:00
tags: [ClickHouse, OLAP, 列式存储, 数据库选型, StarRocks]
description: ClickHouse靠列式存储、向量化执行和稀疏索引做到百毫秒级聚合查询，但多表JOIN是短板。含vs StarRocks选型建议。
categories: 学习
---

💡 ClickHouse 把单表聚合做到百毫秒级，但多表 JOIN 是架构性短板——没有全局查询计划是根因。选型时先问自己：你的场景是单表扫描还是多表关联？

## 背景

OLAP（联机分析处理，专门做数据分析查询的数据库）领域近年竞争激烈。ClickHouse 是增长最快的系统之一。

DB-Engines 2026 年 7 月排名中，ClickHouse 列第 26 位（25.27 分），较去年上升 4 位，年度得分增长 6.73。技术媒体将其定位为"PB 级云 OLAP 事实标准"。

## 关键竞争力

ClickHouse 的竞争力来自四个方面。

### 极致单表查询性能

ClickHouse 是"真正的列式数据库"——数据按列存储、按列执行、按列压缩。

它的向量化执行模型（一次处理一批数据而非逐行）配合 SIMD 指令（CPU 的并行计算指令集），让单表聚合查询稳定进入百毫秒级。

### MergeTree 家族与物化视图

ClickHouse 把聚合、归档、去重等操作推迟到后台合并阶段执行，写入路径非常轻。

物化视图本质是插入触发器：新数据写入时自动聚合，查询时直接读预聚合结果。这种"把计算从查询时移到写入时"的模式，可带来 900 倍查询加速。

### 存算分离

ClickHouse Cloud 用 SharedMergeTree 表引擎把数据存到 S3 等共享对象存储。2025 年 7 月发布的 Shared Catalog 把元数据也集中管理，计算节点彻底无盘化，可实现秒级弹性扩缩。

### 开放生态

ClickHouse 25.x 完成了 Apache Iceberg 双向集成、Delta Lake 写入、OneLake 查询等数据湖互操作能力。

## 软件架构

ClickHouse 是 C++ 单体二进制，无外部依赖，单进程承载所有功能。架构分四层：

- 访问层：支持 HTTP、TCP、PostgreSQL、MySQL、gRPC 多种协议
- 查询处理层：SQL 解析 → 语法树 → 执行管道，含规则优化器和向量化执行
- 存储层：MergeTree 家族为主，另有 Memory、Distributed、Kafka 等引擎
- 协调层：ClickHouse Keeper（兼容 ZooKeeper 协议）负责元数据和复制

关键特征：采用 shared-nothing 分布式模型，数据按分片表达式分布到多节点，每片可多副本。

与 StarRocks 的根本差异：StarRocks 用 FE（前端节点）和 BE（后端节点）分离架构，有全局查询计划。ClickHouse 没有全局查询计划，分布式查询靠"下推到本地表 + 合并结果"——这是它多表 JOIN 弱的架构根因。

## MergeTree 存储引擎与稀疏索引

### 稀疏主索引

MergeTree 是核心存储引擎。数据按主键排序存储在不可变的"数据块"中。

稀疏索引的核心机制：主键索引只记录每 8192 行的主键值，而非每行。索引常驻内存，消耗可忽略，支持单服务器万亿行数据。

```sql
CREATE TABLE telecom_kpi (
    event_time DateTime,
    ne_id UInt32,
    kpi_value Float64
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (event_time, ne_id)
SETTINGS index_granularity = 8192;
```

适用边界：稀疏索引不适合高频点查。每次主键查询要读取整 8192 行数据块并解压。如果做精确 ID 查询，StarRocks 的主键表更合适；如果做时间范围扫描加聚合，ClickHouse 优势明显。

### MergeTree 家族变体

- MergeTree：标准合并，通用场景
- ReplacingMergeTree：同主键保留最新版本，适合版本化数据
- SummingMergeTree：同主键数值求和，适合累加指标
- AggregatingMergeTree：合并聚合状态，常作物化视图目标表
- CollapsingMergeTree：按标记列折叠行，适合状态机变更

### 数据跳数索引

除主键稀疏索引外，还支持二级跳数索引：MinMax（范围过滤）、Set（低基数等值）、bloom_filter（高基数等值）、text（25.10 版倒排索引）、vector_similarity（向量搜索，25.8 版发布）。

25.9 版引入"流式跳数索引"，索引检查与数据读取交错执行，在 10 亿行表上带来 2.4 倍加速。

## 向量化执行与查询优化

### SIMD 多版本与 LLVM 编译

ClickHouse 为每段热点代码维护多个计算内核：兼容旧 CPU 的非向量化版、自动向量化的 AVX2 版、手写 AVX-512 版，运行时自动选最快的。

LLVM 运行时编译用于"算子融合"：把 `a * b + c + 1` 编译成单一算子，减少函数调用开销。

### 全局 JOIN 重排序

25.9 版引入了 ClickHouse 历史上首个全局 JOIN 重排序能力，是其长期短板的关键改进。

基准数据惊人：6 表 TPC-H 查询，无统计信息时耗时 3903 秒、峰值内存约 100GB；启用后降至 2.7 秒、内存低于 4GB——1450 倍加速、25 倍内存降低。

仍有限制：需手动创建统计信息，outer join 和子查询覆盖有限。

### 物化视图增量聚合

核心模式是"插入触发器 + 状态聚合"：

```sql
CREATE TABLE packets_raw (...)
  ENGINE = MergeTree() ORDER BY (ts, ne_id);

CREATE TABLE packets_hourly (
    hour DateTime, ne_id UInt32,
    bytes_sum AggregateFunction(sum, UInt64)
) ENGINE = AggregatingMergeTree()
  ORDER BY (hour, ne_id);
...
```

关键工程经验：

- GROUP BY 列必须与目标表排序键对齐
- JOIN 在物化视图中代价高，推荐用字典查询替代，快最多 25 倍
- 5 个以上物化视图挂同一源表会引发写放大

### 适用边界

- JOIN 弱于 StarRocks：ClickHouse 无成熟的基于代价的优化器
- 并发较弱：500 并发下延迟显著退化，StarRocks 通过查询排队更稳定
- 更新代价高：单行更新可能触发整个数据块重写，推荐用轻量更新
- 小批量插入不友好：建议用异步插入缓冲

## 与 StarRocks 对比

| 维度 | ClickHouse | StarRocks |
|------|------------|-----------|
| 架构 | shared-nothing / 共享存储 | FE/BE 分离，双模支持 |
| 主索引 | 稀疏（8192 行粒度） | 主键表支持点查 |
| 多表 JOIN | 弱（TPC-H 无法完成基准） | 强（SSB 快 1.87 倍） |

| 维度 | ClickHouse | StarRocks |
|------|------------|-----------|
| 单表聚合 | 强（ClickBench 胜出） | 强 |
| 高并发 | 500 并发退化 | 资源池维持稳定 |
| 压缩比 | 极佳（10-20 倍） | 佳（10-15 倍） |

基准数据对比：

- SSB 100GB：StarRocks 3.5.0 总耗时 992ms，ClickHouse 25.3.3 耗时 1858ms，StarRocks 快 1.87 倍
- TPC-H 多表 JOIN：StarRocks 较 ClickHouse 快 3-5 倍；ClickHouse 在 StarRocks 官方基准中"无法完成 TPC-H 测试集"
- ClickBench 单表：ClickHouse 通常胜出，因宽表扫描效率极高

核心结论：场景以多表关联为主的，StarRocks 在 SSB 快 1.87 倍、TPC-H 场景 ClickHouse 无法完成基准，选 StarRocks 合理。ClickHouse 的稀疏索引设计和物化视图增量聚合值得借鉴。两者都已具备存算分离能力，无需为此更换引擎。

## 电信行业案例

- 西班牙 Grupo Masmovil：用 ClickHouse 监控 RAN 网络，存储节省 16 倍、资源消耗降低 10 倍、数据延迟从 3 小时降至 15 分钟
- 德国 BENOCS：为全球头部电信运营商提供网络流量监控，依赖稀疏索引和时间序列邻近匹配

## 这对读者意味着什么

如果你在做时序数据分析（网络指标、日志、遥测），ClickHouse 的单表扫描性能确实极强。压缩比 10-20 倍意味着存储成本大幅降低，稀疏索引让万亿行数据的索引内存可忽略。这些都是实打实的工程优势。

但如果你需要多表 JOIN（比如关联用户表、订单表、产品表做综合分析），ClickHouse 不是好选择。没有全局查询计划是架构层面的短板，25.9 版的全局 JOIN 重排序虽然有 1450 倍加速，但仍需手动建统计信息，覆盖有限。这种场景 StarRocks 更合适。

从技术借鉴角度，ClickHouse 有两个模式值得在 StarRocks 上验证：稀疏主索引（万亿行索引内存可忽略）和物化视图增量聚合（把计算从查询时移到写入时，数百倍加速）。这两个模式的核心思想——"用写入时的计算换查询时的速度"——在任何 OLAP 引擎上都有参考价值。

## 参考链接

- [ClickHouse官方文档](https://clickhouse.com/docs/en/)
- [ClickHouse架构设计](https://clickhouse.com/docs/en/development/architecture)
- [ClickHouse Wikipedia](https://en.wikipedia.org/wiki/ClickHouse)
- [StarRocks官方文档](https://docs.starrocks.io/)
- [StarRocks GitHub](https://github.com/StarRocks/starrocks)

## ✅ 总结

- ClickHouse 单表查询性能极强，但多表 JOIN 是架构性短板——没有全局查询计划是根因。场景以多表关联为主的，StarRocks 更合适
- 稀疏主索引和物化视图增量聚合是两大技术亮点：前者让万亿行索引内存可忽略，后者带来数百倍查询加速，值得在 StarRocks 上验证等价能力
- 两者存算分离能力都已具备，ClickHouse Cloud 的无盘化设计是工程领先实践，但不需要为此更换技术路线
