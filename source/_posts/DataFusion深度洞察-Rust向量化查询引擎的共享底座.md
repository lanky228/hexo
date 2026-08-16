---
title: DataFusion深度洞察——Rust向量化查询引擎的共享底座
date: 2026-08-03 06:00:00
tags: [数据库, Rust, DataFusion, 查询引擎, 向量化]
categories: 学习
---

💡 DataFusion 不是数据库，而是 Rust 生态唯一提供"完整 SQL+完整优化器+完整执行层"的可嵌入查询引擎库。它的核心价值不在单点性能超越 DuckDB，而在于"共享底座"——InfluxDB 3.0、GreptimeDB、Comet 等 10+ 产品复用同一引擎，一次修复全生态受益。

## 背景

数据通信产品线查询引擎选型面临"自研 vs 采购 vs 嵌入"的三难。

完全自研查询引擎（parser+optimizer+executor）是 5 年以上人年投入，业界已证明不可持续。直接采购 DuckDB 等完整数据库则受限于 C++ 闭源内核难以深度定制。Calcite 仅提供优化器层无执行能力，补齐执行层仍需自行实现。

DataFusion 作为 Rust 原生的全栈查询引擎库，提供了第四条路径——嵌入成熟引擎并按需扩展。其模块化设计允许只复用 parser 或只复用 optimizer，降低了引入成本。

2024 年 SIGMOD（国际数据库顶级会议）工业论文正式收录 DataFusion 架构，证明其性能与 DuckDB 在标准基准上处于同一区间。InfluxDB 3.0、GreptimeDB、Coralogix、Spice.ai、Comet 等 10+ 产品已将其作为底座，形成"一次修复、全生态受益"的共享底座效应。

## DataFusion 解决什么问题

DataFusion 起源于 Apache Arrow 项目，最初作为 Arrow 的 Rust 实现中的查询层组件，2020 年成为 Apache 顶级项目独立孵化。

其诞生背景是 Rust 数据生态的"SQL 层真空"——arrow-rs 提供了高效的列式内存格式和计算内核，但缺少从 SQL 字符串到执行结果的完整查询能力。Polars 填补了 DataFrame 层，但 SQL 层仍空白。

DataFusion 的目标定位明确写在官方文档中：成为新式数据系统（数据库、DataFrame 库、机器学习与流处理应用）的首选查询引擎。

### 三个具体痛点

**Python 数据分析性能瓶颈**。Python 在 OLAP 查询的向量化执行上受限于 GIL（全局解释器锁）和解释器开销。DataFusion 通过 Rust 原生向量化执行提供数量级性能提升，同时通过 datafusion-python 绑定保持 Python 可用性。

**嵌入式分析缺少可扩展引擎**。DuckDB 虽然是嵌入式分析标杆，但其 C++ 内核的扩展点是"加载预编译扩展"，无法在源码级深度定制算子与优化规则。DataFusion 的扩展点是 Rust trait（TableProvider/OptimizerRule/ExecutionPlan），允许下游项目在编译期注入自定义逻辑。

**Rust 生态缺少 SQL 层**。在 DataFusion 之前，Rust 开发者若要为自研数据库添加 SQL 支持，只能自行实现 parser+planner+optimizer，这是多年度工程。DataFusion 将其压缩为 `cargo add datafusion` 一行依赖。

### 关键定位判断

DataFusion 不是数据库，是"可嵌入的查询引擎框架"。

它没有存储引擎（依赖 TableProvider 外部提供数据）、没有事务管理（无 WAL 无 ACID）、没有持久化层、没有服务进程（作为库嵌入宿主进程）。

这一定位决定了它的使用方式——产品线不会"部署 DataFusion"，而是"在 Rust 应用中引入 DataFusion 库"。

## 关键竞争力技术

### Arrow 原生零拷贝内存

DataFusion 以 Apache Arrow 作为唯一内存格式，所有算子间数据流转均以 Arrow RecordBatch（行式表的横向切片）为单位。RecordBatch 是一组等长列式数组遵循既定 schema，每个列是连续内存数组，所有列行数相同。

这一设计带来三个性能优势：

- **零拷贝跨系统交换**：Arrow 标准化了列式内存布局，不同系统（Rust/Python/Java）和不同进程间可通过共享内存或 Arrow Flight RPC 传递 RecordBatch 而无需序列化
- **SIMD 友好列式布局**：列数据连续存储，CPU 可对一批值做数据并行（SIMD 指令），编译器自动向量化
- **不可变快照并行安全**：RecordBatch 一旦创建不可修改，任何转换产生新 RecordBatch，无需锁即可在多线程间共享

与 DuckDB 的对比在这里尤为清楚：DuckDB 使用自研的 DataChunk（2048 元组）作为执行单元，与 Arrow 的互操作需要转换层。DataFusion 直接以 Arrow 为执行单元，对已存在于 Arrow 格式的数据零序列化成本。

### 自建 SQL 解析器

DataFusion 的 SQL 解析使用 sqlparser-rs，这是 Apache Arrow 社区维护的独立 Rust SQL 解析器，而非 Java 生态普遍采用的 Apache Calcite。

这一选择是架构层面的关键决策：

- **Rust 原生**：纯 Rust 实现，无 JNI（Java 原生接口）开销，无 JVM 依赖，与 DataFusion 的 Rust 全栈一致
- **可独立使用**：sqlparser-rs 作为独立 crate 发布，产品线可仅引入 SQL 解析能力而不引入 planner/executor
- **方言可扩展**：支持 MySQL/PostgreSQL/SQLite/Hive/BigQuery 等多种方言的 dialect trait，产品线可自定义数通信方言

与 Calcite 的对比：Calcite 是 Java 生态的优化器框架，提供 parser+validator+optimizer 但无执行层。DataFusion 是 Rust 生态的全栈引擎，parser+planner+optimizer+executor 一体。产品线若需 Java 侧优化器选 Calcite，若需 Rust 侧全栈查询能力选 DataFusion。

### 规则+代价双驱动优化器

DataFusion 的优化器分为三层：

**AnalyzerRules（语义规则）**：类型强制（type_coercion）、表达式简化（simplify_expressions），确保计划语义正确。

**OptimizerRules（逻辑优化）**：谓词下推（filter_push_down）、投影下推（projection_push_down）、列裁剪、常量折叠、子查询去关联、连接重排序、公共子表达式消除、限制下推、单 distinct 聚合转 group_by 等。

**PhysicalOptimizerRules（物理优化）**：聚合统计（aggregate_statistics）、连接选择（join_selection，选 HashJoin 还是 MergeJoin）、批合并（coalesce_batches）、重分区（repartition）等。

代价模型依赖表级和列级统计信息（ColumnStatistics：null 计数、min/max、distinct 值计数）做选择性估算。还使用边界分析与区间算术对 `a > 2500 AND a <= 5000` 这类谓词构建精确选择性估计。

统计信息包裹在 Precision 类型中，标识精确值还是估算值，使优化器能判断估算可靠性。

### 流式向量化执行引擎

DataFusion 执行引擎采用经典 Volcano 拉模型（pull-based），每个 ExecutionPlan 实现 `execute()` 返回 SendableRecordBatchStream——一个 Tokio 友好的 Arrow RecordBatch 异步流。

调用 `next().await` 增量计算并返回下一个 RecordBatch，算子按需从上游拉取数据。并行性通过 Volcano 风格的 Exchange 操作（RepartitionExec）实现，平衡多核负载。

选择拉模型而非推模型（DuckDB 的 push-based）的原因：DataFusion 的目标部署是嵌入式低延迟短查询，拉模型的自然背压与异步 I/O 原生支持更适合此场景。DataFusion 的 SIGMOD 论文证明拉模型在实践中达到与 DuckDB 推模型相近的扩展性。

### 模块化与深度扩展点

DataFusion 的扩展点覆盖查询全生命周期，每个扩展点都是 Rust trait：

| 扩展点 | trait | 作用 | 典型下游用法 |
|--------|-------|------|-------------|
| 数据源 | TableProvider | 提供 schema 与 scan 计划 | InfluxDB 注册时序表 |
| 目录 | CatalogProvider | 自定义 catalog/schema/table 层级 | 多租户隔离 |
| 查询语言 | LogicalPlanBuilder | 跳过 SQL 直接构建计划 | 自定义 DSL、DataFrame API |
| 标量 UDF | ScalarUDF | 自定义标量函数 | 时序函数、地理函数 |
| 聚合 UDAF | AggregateUDF | 自定义聚合函数 | 分位数、sketch |
| 窗口 UDWF | WindowUDF | 自定义窗口函数 | 时序窗口 |
| 分析规则 | AnalyzerRule | 语义重写 | 类型扩展 |
| 逻辑优化 | OptimizerRule | 计划重写 | 谓词下推定制 |
| 物理优化 | PhysicalOptimizerRule | 物理计划重写 | 自定义连接策略 |
| 物理算子 | ExecutionPlan | 自定义执行节点 | 时序去重、Parquet 合并 |
| 查询规划器 | QueryPlanner | 替换 LogicalPlan→ExecutionPlan 映射 | 全自定义执行 |

这一扩展深度是 DataFusion 相对 DuckDB 的核心差异——DuckDB 的扩展是"加载预编译动态库"，DataFusion 的扩展是"实现 trait 编译进二进制"，后者允许下游项目在源码级重塑引擎行为。

### Ballista 分布式执行扩展

DataFusion 本身是单进程嵌入式引擎，分布式执行通过子项目 Ballista 扩展。

Ballista 集群由 scheduler 进程和 executor 进程组成，均以原生 Rust 二进制运行，支持 Docker Compose 与 Kubernetes 部署。查询流程：客户端提交 SQL 或 LogicalPlan 到 scheduler → scheduler 创建 ExecutionGraph（物理计划按 stage 切分）→ executor 轮询领取任务执行 → stage 间通过 shuffle 重分区。

Ballista 使用 Arrow IPC 格式作为 shuffle 文件与 executor 间数据交换格式，支持 Arrow Flight SQL JDBC 驱动接入 DataGrip/Tableau 等工具。

其调度支持静态（计划时全量 stage DAG）与自适应（每 stage 完成后用实际行数字节重优化剩余计划）两种模式。

⚠️ 需注意：Ballista 目前仍存在与 DataFusion 单进程版的能力 gap，部分 SQL 在分布式模式下不可用，官方明确"仍在弥合此差距"。Ballista 的多数用户并非直接使用 Ballista，而是以 Ballista 为底座构建自有分布式引擎。

## 端到端 SQL 执行流程

以 `SELECT name FROM 'data.parquet' WHERE id > 10` 为例，追踪 SQL 从输入到输出的完整调用链。

### SQL 解析

输入 SQL 字符串，输出 AST（抽象语法树）Statement。

调用链：SessionContext::sql → SqlToRel::parse_sql → sqlparser::Parser::parse_sql → 返回 Statement。SQL 解析本身是 CPU 密集的字符串处理，超长 SQL（数 KB）解析耗时可达毫秒级，但相对执行通常可忽略。

### 逻辑计划构建

输入 AST Statement，输出 LogicalPlan（关系代数表达式树，DAG）。

调用链：SqlToRel::sql_statement_to_plan → 名称与类型解析（binding，将 name/id 绑定到 TableProvider 提供的 schema）。名称解析需遍历 schema 做符号查找，复杂查询（多表 JOIN+子查询）的 binding 可耗时。

### 分析规则

输入初始 LogicalPlan，输出语义正确的 LogicalPlan（类型强制后）。

调用链：Optimizer::with_rules → AnalyzerRule::rewrite（type_coercion、simplify_expressions 等）。规则遍历整棵计划树，深度大的树（多层嵌套子查询）遍历耗时。

### 逻辑优化

输入分析后的 LogicalPlan，输出优化后的 LogicalPlan。

调用链：Optimizer::optimize → 多轮 OptimizerRule::rewrite（max_passes 默认 16）。关键优化：filter_push_down 将 `id > 10` 下推到 TableScan 层；projection_push_down 将 TableScan 的投影裁剪为只读 id 和 name 两列。

规则迭代至不动点（fixpoint），max_passes 限制了迭代次数，但复杂查询仍可能接近上限。

### 物理计划构建

输入优化后的 LogicalPlan，输出 ExecutionPlan（物理算子树）。

调用链：DefaultPhysicalPlanner::create_initial_plan → DFS 扁平化 LogicalPlan 树 → 从叶子并发构建 ExecutionPlan（leaf-to-root，planning_concurrency 控制并发度）。

物理计划构建是异步并发任务，大计划的并发构建受 planning_concurrency 限制。

### 物理优化

输入初始 ExecutionPlan，输出优化后的 ExecutionPlan。

调用链：PhysicalOptimizerRule::rewrite（join_selection、coalesce_batches、repartition、add_merge_exec 等）。join_selection 依赖统计信息做代价估算，统计信息缺失时退化默认选择。

### 执行

输入优化后的 ExecutionPlan，输出 SendableRecordBatchStream（Arrow RecordBatch 异步流）。

数据流：Parquet 文件 → DataSourceExec 读取 RecordBatch → FilterExec 过滤(id>10) → ProjectionExec 保留 name 列 → 结果 RecordBatch。

关键特性：流式执行，每个算子增量处理一个 RecordBatch（约 batch_size 行），非 pipeline breaker 算子可逐批产出。pipeline breaker（全排序、hash 聚合）需读完输入才产出。

并行性：多分区计划在 Tokio runtime 的多线程上并发执行，RepartitionExec 做 Exchange 式负载均衡。

性能瓶颈：pipeline breaker（sort/hash_agg）需在内存中累积状态，超出 MemoryPool 预算时 spill 到磁盘。shuffle/重分区的网络与磁盘 I/O 是分布式场景瓶颈。

### 整体调用链总结

```
SQL String
  → sqlparser::Parser::parse_sql           → AST Statement
  → SqlToRel::sql_statement_to_plan        → LogicalPlan (DAG)
  → AnalyzerRules::rewrite                 → LogicalPlan (语义正确)
  → OptimizerRules::rewrite (≤16 passes)   → LogicalPlan (优化后)
  → DefaultPhysicalPlanner                 → ExecutionPlan (物理算子树)
  → PhysicalOptimizerRules::rewrite        → ExecutionPlan (物理优化后)
  → ExecutionPlan::execute                 → SendableRecordBatchStream
  → stream.next().await (Tokio拉模型)       → RecordBatch (Arrow列式)
  → collect                                → Vec<RecordBatch> (结果)
```

## 同类软件对比

DataFusion 的竞争定位需从多个维度对比同类系统。由于系统众多，按主题分三组对比。

### 基础属性对比

| 系统 | 语言 | 定位 | 嵌入方式 |
|------|------|------|----------|
| DataFusion | Rust | 可嵌入查询引擎框架 | Rust 库（cargo add） |
| DuckDB | C++ | 嵌入式分析数据库 | 进程内（C++ 绑定） |
| Calcite | Java | 优化器框架 | Java 库 |
| Polars | Rust | DataFrame 库 | Rust 库/Python 包 |
| ClickHouse | C++ | 完整 OLAP 数据库 | 服务端进程 |
| Spark SQL | Scala | 分布式计算引擎 | 服务端进程 |

### 查询能力对比

| 系统 | SQL 解析 | 优化器 | 执行层 |
|------|----------|--------|--------|
| DataFusion | sqlparser-rs（自建） | 规则+代价（统计+边界分析） | 向量化（Arrow，Volcano 拉模型） |
| DuckDB | libpg_query（PG 派生） | CBO 动态规划+贪心 | 向量化（DataChunk，push 模型） |
| Calcite | JavaCC 自建 | 规则+代价（最成熟） | 无执行层 |
| Polars | 有限 SQL | 规则（投影/谓词下推） | 向量化（Arrow，lazy DAG） |

### 存储与扩展对比

| 系统 | 存储 | 事务 | 扩展深度 |
|------|------|------|----------|
| DataFusion | 无（TableProvider 提供） | 无 | trait 级（编译期注入） |
| DuckDB | 自研列式+单文件+ACID | MVCC | 动态库加载 |
| ClickHouse | MergeTree+ACID | ACID | 预编译扩展 |
| Spark SQL | 无（依赖 HDFS/S3） | 无 | Catalyst 扩展 |

### 对比结论

**vs DuckDB**：DuckDB 是完整数据库（含存储/ACID/持久化），开箱即用；DataFusion 是查询引擎框架，无存储无事务，需自行实现 TableProvider。DuckDB 适合"直接查询数据"的产品级场景，DataFusion 适合"构建数据系统"的工程级场景。性能上两者在 TPC-H 标准基准处于同一区间。

**vs Calcite**：Calcite 是 Java 生态优化器中间件，无执行层；DataFusion 是 Rust 全栈引擎。产品线若仅需优化器层选 Calcite，若需全栈查询能力选 DataFusion。两者并非直接竞争，而是不同语言生态的互补层。

**vs Polars**：Polars 是 Rust DataFrame 库，SQL 支持有限（无完整 JOIN，9/22 TPC-H 查询因缺标量子查询支持而失败）。DataFusion 同时提供完整 SQL 与 DataFrame API，SQL 能力远超 Polars。

**vs ClickHouse**：ClickHouse 是完整 OLAP 数据库，DataFusion 是嵌入式框架无存储。两者不在同一选型维度。

**vs Spark SQL**：Spark 是 JVM 分布式重型计算引擎，DataFusion 是 Rust 嵌入式轻量引擎。Comet 子项目将 DataFusion 作为 Spark 的 native 加速器，是两者的融合路径。

## 为什么 DataFusion 最出彩

### Rust 生态 SQL 查询引擎标杆

DataFusion 是 Rust 生态唯一提供"完整 SQL+完整优化器+完整执行层"的开源查询引擎。

在 Rust 数据栈中，arrow-rs 提供内存格式与计算内核，Parquet-rs 提供文件格式，sqlparser-rs 提供 SQL 解析，DataFusion 在其上构建查询引擎层，填补了"从 SQL 到执行结果"的完整能力空白。这一位置使其成为 Rust 数据系统的"事实标准底座"。

### 共享底座效应与生态采纳

DataFusion 最出彩的不是单点性能，而是"共享底座"模式——多个产品复用同一引擎，一次修复全生态受益。

已采纳 DataFusion 的产品清单（部分）：

| 产品 | 类型 | DataFusion 用法 |
|------|------|----------------|
| InfluxDB 3.0 (IOx) | 时序数据库 | 查询引擎核心，FDAP 栈组件 |
| Comet | Spark 加速器 | Spark stage 内 native 执行层 |
| Ballista | 分布式查询引擎 | DataFusion 的分布式包装 |
| GreptimeDB | 云原生时序数据库 | 查询引擎基座 |
| Spice.ai | 联邦查询引擎 | 40+ 数据源联邦查询核心 |
| Coralogix | 可观测平台 | 日志查询引擎 |
| ROAPI | API 网关 | 自动 REST/GraphQL API 生成 |
| ParadeDB | 搜索数据库 | Postgres 内分析查询 |
| Sail | 分布式 Rust 引擎 | DataFusion 的分布式包装 |
| OpenObserve | 可观测平台 | 日志/指标/trace 查询 |

InfluxDB 3.0 的案例最具代表性：InfluxData 在 2020 年判断自研 Go 引擎不可持续，选择 Rust+Arrow+DataFusion+Parquet 重写 IOx，将工程投入聚焦于时序特有能力（ingest、InfluxQL、Parquet 合并），通用查询能力复用 DataFusion。

结果是子秒级查询、100× ingest 提升、Parquet 原生存储，且无需维护自研查询引擎。这一案例验证了"共享底座"的工程经济性。

### Arrow 生态深度集成

DataFusion 与 Apache Arrow 生态的集成是所有引擎中最深的：

- **Arrow 内存**：唯一内存格式，算子间零序列化
- **Arrow Flight**：网络传输协议，零拷贝 RPC
- **Parquet**：列式存储格式，原生 reader
- **Arrow Dataset**：多文件数据集抽象

这一深度集成使 DataFusion 在"数据已 Arrow 格式"的场景（Arrow Flight 传输的数据、内存 Arrow 缓存、流式系统 Arrow 输出）有不可替代的零序列化优势。

### 社区活跃度

DataFusion 是 Apache 软件基金会顶级项目，采用 Apache 治理（非单一公司主导）。

GitHub 贡献者数与版本发布节奏保持高频，6 周一个 minor 版本（v46-v55 持续发布），每个版本含性能改进与新优化规则。社区有 InfluxData、Greptime、Coralogix、Spice.ai 等多家公司全职贡献者，形成"商业用户反哺社区"的正循环。

### 行业趋势判断

CMU 教授 Andy Pavlo 在 2022 年数据库回顾中判断：Velox、DataFusion、Polars 等可复用查询执行框架的普及，意味着 5 年内所有 OLAP DBMS 的向量化执行能力将趋于等效。

云时代存储层大家相同（S3/EBS），DBMS 的差异化将转移到 UI/UX 和查询优化等难以量化的维度。这一判断印证了 DataFusion 的"共享底座"定位——查询执行层的自研价值正在商品化，复用成熟引擎是更理性的工程选择。

## 与产品线查询引擎的关联

DataFusion 对数据通信产品线查询引擎选型的关联体现在三个方向。

### 方向一：Rust 侧 SQL 验证与改写层

产品线 AI 查询服务从"AI 生成统一 SQL→Calcite 事后改写"向"AI 感知底层库直接生成该库 SQL"演进。

这一演进若在 Rust 侧实现，DataFusion 的 sqlparser-rs+LogicalPlan 可作为 SQL 验证与方言改写的中间表示——比 Calcite 的 Java JVM 依赖更轻量，比自行实现 parser+planner 成本更低。

DataFusion 的 LogicalPlan 是 schema-aware（感知 schema）的关系代数树，可做谓词下推验证、列存在性检查、类型兼容性校验，为 AI 生成 SQL 提供事前验证能力。

### 方向二：嵌入式查询引擎的部分引入路径

产品线三引擎架构（StarRocks/Druid/GaussDB）均为服务端进程，在边缘网管终端、CLI 工具、测试工具等轻量场景存在能力空白。

DuckDB 可作为进程内嵌入式数据库填补，但若产品线需要在 Rust 应用中嵌入查询能力且需深度定制算子（如自定义时序聚合、自定义网络拓扑过滤），DataFusion 的 trait 级扩展比 DuckDB 的动态库加载更可控。

产品线可评估"Rust 工具链+DataFusion+Parquet"的轻量查询工具链。

### 方向三：自研引擎的底座选项

若产品线长期有自研查询引擎需求（如统一 SQL 查询服务、跨库联邦查询），DataFusion 提供了比"从零构建"更现实的底座。

复用 parser+planner+optimizer+executor，聚焦自研产品差异化（如数通信方言、网络拓扑算子、协议日志格式 reader）。InfluxDB 3.0 的案例证明这一路径的工程经济性。

### 产品线适用边界

| 场景 | 适用性 | 依据 |
|------|--------|------|
| Rust 应用内嵌 SQL 查询 | 适用 | 库级嵌入，trait 扩展 |
| AI 生成 SQL 的 Rust 侧验证 | 适用 | sqlparser-rs 独立可用 |
| 边缘网管终端轻量分析 | 可评估 | 无服务进程但需 Rust 工具链 |
| 大规模 OLAP 服务化部署 | 不适用 | 无存储无分布式，Ballista 仍在弥合 gap |
| 替代 StarRocks/Druid/GaussDB | 不适用 | 定位不同，非完整数据库 |
| Java 侧优化器选型 | 不适用 | 选 Calcite（Java 生态） |

## 下一步建议

按验证项、观察项、布局项三层推进。

### 验证项（高优先级）

**sqlparser-rs 独立引入 PoC**：在产品线 AI 查询服务的 Rust 侧验证层引入 sqlparser-rs，做 SQL AST 分析与方言识别，评估其对 StarRocks/Druid/GaussDB 各方言的覆盖度。sqlparser-rs 是独立 crate，支持多方言。

**DataFusion LogicalPlan 验证 PoC**：在 Rust 侧用 DataFusion 的 LogicalPlan 做 AI 生成 SQL 的事前验证（列存在性、类型兼容、谓词下推可行性），对比 Calcite 改写路径的成本与延迟。LogicalPlan 是 schema-aware 关系代数树。

### 观察项（中优先级）

**DataFusion+Parquet 轻量查询工具链**：评估"Rust CLI+DataFusion+Parquet"在网管数据导出与分析工具中的适用性，对比 DuckDB 进程内方案。

**Ballista 分布式能力跟踪**：跟踪 Ballista 与 DataFusion 单进程版能力 gap 的弥合进度，评估其作为产品线联邦查询引擎底座的可行性。

### 布局项（长期评估）

**DataFusion 自研引擎底座评估**：若产品线长期有统一 SQL 查询服务自研需求，评估以 DataFusion 为底座复用 parser+planner+optimizer+executor、聚焦自研产品差异化的工程经济性。InfluxDB 3.0 案例已验证。

**FDAP 栈端到端评估**：评估"Arrow Flight 传输+DataFusion 查询+Arrow 内存+Parquet 存储"全链路在产品线跨系统数据交换中的零序列化优势。FDAP 栈是 InfluxData 判断的分析系统未来基础。

## ✅ 总结

Apache DataFusion 是 Rust 生态唯一提供"完整 SQL+完整优化器+完整执行层"的开源查询引擎框架，定位是可嵌入库而非数据库——无存储、无事务、无服务进程。这决定了它适合 Rust 应用内嵌 SQL 查询、AI 生成 SQL 的 Rust 侧验证、自研引擎底座三个方向，不适合大规模 OLAP 服务化部署。

DataFusion 最出彩的不是单点性能，而是"共享底座"模式——InfluxDB 3.0、GreptimeDB、Comet、Ballista、Spice.ai 等 10+ 产品复用同一引擎。CMU 教授 Andy Pavlo 判断查询执行层的自研价值正在商品化，5 年内所有 OLAP DBMS 的向量化执行能力将趋于等效。复用成熟引擎而非自研，是更理性的工程选择。

DataFusion 相对 DuckDB 的核心差异在扩展深度——DuckDB 的扩展是"加载预编译动态库"，DataFusion 的扩展是"实现 Rust trait 编译进二进制"。后者允许下游项目在源码级重塑引擎行为。产品线若需深度定制算子选 DataFusion，若需开箱即用选 DuckDB，两者是"工程级可定制"与"产品级开箱即用"的分层互补。

## 参考资料

- [Apache DataFusion Introduction](https://datafusion.apache.org/user-guide/introduction.html)
- [Apache DataFusion SIGMOD 2024 Paper](https://dl.acm.org/doi/10.1145/3626246.3653368)
- [Apache DataFusion Architecture (docs.rs)](https://docs.rs/datafusion/latest/datafusion/index.html#architecture)
- [Flight, DataFusion, Arrow, and Parquet: Using the FDAP Architecture to build InfluxDB 3.0](https://www.influxdata.com/blog/flight-datafusion-arrow-parquet-fdap-architecture-influxdb/)
- [Apache DataFusion for Data Engineers](https://dev.to/gowthampotureddi/apache-datafusion-for-data-engineers-rust-native-query-engine-under-ballista-influxdb-3-comet-2obb)
- [Engineering a Time Series Database Using Open Source (InfoQ)](https://www.infoq.com/articles/timeseries-db-rust/)
- [DuckDB 嵌入式分析数据库洞察（本仓库）](https://github.com/datacom-insight/insight-report/blob/main/insight-report-duckdb/DuckDB-嵌入式分析数据库洞察.md)
- [ClickHouse 列式 OLAP 洞察（本仓库）](https://github.com/datacom-insight/insight-report/blob/main/insight-report-clickhouse/)
- [Apache Calcite vs 新一代查询框架竞争力洞察（本仓库）](https://github.com/datacom-insight/insight-report/blob/main/insight-report-calcite-vs-new-frameworks/)
- [Apache DataFusion GitHub Repository](https://github.com/apache/datafusion)
- [Apache DataFusion FAQ (vs DuckDB/Polars/Velox)](https://datafusion.apache.org/user-guide/faq.html)
- [Gentle Arrow Introduction](https://datafusion.apache.org/user-guide/arrow-introduction.html)
- [Apache DataFusion Query Optimizer documentation](https://datafusion.apache.org/library-user-guide/query-optimizer.html)
- [Ballista Architecture](https://datafusion.apache.org/ballista/contributors-guide/architecture.html)
- [Apache DataFusion Ballista Overview](https://datafusion.apache.org/ballista/user-guide/introduction.html)
- [DataFusion DefaultPhysicalPlanner source](https://github.com/apache/datafusion/blob/main/datafusion/core/src/physical_planner.rs)
- [Apache DataFusion vs DuckDB (Spice.ai)](https://spice.ai/learn/apache-datafusion-vs-duckdb)
- [Ibis benchmarking: DuckDB, DataFusion, Polars (TPC-H)](https://ibis-project.org/posts/ibis-bench/)
- [Andy Pavlo, 2022 Databases Retrospective (OtterTune)](https://ottertune.com/blog/2022-databases-retrospective/)
