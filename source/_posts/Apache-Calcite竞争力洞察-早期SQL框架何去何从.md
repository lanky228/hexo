---
title: Apache Calcite竞争力洞察——早期SQL框架何去何从
date: 2026-08-03 03:00:00
tags: [数据库, Apache Calcite, 优化器, 查询引擎]
categories: 学习
---

💡 一个没有执行层的优化器框架，在向量化+分布式+全栈自研时代，究竟是被颠覆的旧物，还是不可替代的底座？答案是：当中间件用，它五年内仍不可替代；当引擎用，它已经输了。

## 背景

数据通信产品线查询服务的核心命题是"统一 SQL、感知底层库、生成该库 SQL"。这条路线天然要把 SQL 解析优化和底层执行解耦——Calcite 正是这种解耦哲学的最成熟实现。

但环顾四周，StarRocks、DuckDB、ClickHouse、Trino 这些标杆无一使用 Calcite。使用 Calcite 的项目（Flink、Drill、Phoenix、Hive、Kylin）多在流式或遗留大数据场景。"优化器框架"这条路线在新一代 OLAP 引擎中几乎零采用。

这就引出核心问题：Calcite 这种早期单体 SQL 框架，竞争力还在不在？还有生命力吗？这不是学术问题——它直接决定产品线查询服务选型，是拥抱 Calcite 做联邦与方言改写，还是走 StarRocks/DuckDB 式全栈自研。

## 五个核心判断

📌 先把结论摆出来，下面再展开。

### Calcite 没有死，反而很健康

2026 年 5 月发布的 1.42.0 单版本解决 249 个 issue、39 位贡献者参与。ASF 董事会连续多季度评为"Super healthy"，82 位 committer、33 位 PMC，社区活跃度不降反升。把它当"过时的旧框架"是事实层面的误判。

### 新框架绕开是性能竞争的必然

StarRocks、DuckDB、ClickHouse、Trino 都自研 SQL 全栈。根本原因是优化器与执行器的紧耦合才能榨取极限性能——这与 Calcite 的"模块化、可组合"哲学直接冲突。不是 Calcite 不好，是性能护城河要求协同设计。

### DataFusion 不基于 Calcite

一个被广泛传播的误解需要纠正：DataFusion 并不"基于 Calcite 的 SQL 前端"。它使用 Rust 的 `sqlparser-rs` 自建解析与计划链路。SIGMOD 2024 论文明确将其与 Calcite 并列为"可组合数据系统"的两类不同实现。

### 真正独特价值是方言改写与联邦适配

1.37 起陆续加入 StarRocks、Doris、DuckDB、SQLite、Trino 方言。它正在做一件讽刺但正确的事：为不使用自己的竞争对手提供方言互译能力。

### 生命力上限是中间件不是引擎

作为"SQL 优化器中间件"在 5 年内仍有持续需求。但天花板清晰——它永远成不了执行引擎，"嵌入式优化器即服务"是唯一有想象力的突破口。

## Calcite 现状：被低估的优化器中间件

### 项目基本面：远比想象的健康

把 Calcite 描述成"早期单体、正在衰退"是常见但错误的印象。从 ASF 董事会会议纪要看，Calcite 在 2025 年 Q4 的状态是"ongoing (high activity)"，社区自评"Super healthy"。

2025 年 Q4 单季度 142 个 JIRA 开、151 个关，关闭速度快于开启速度——这在开源项目中相当罕见。GitHub 5.1k star、2.5k fork，1.42.0 于 2026-05-31 发布，39 位贡献者、249 个 issue；1.41.0 于 2025-11-01 发布，41 位贡献者、155 个 issue。

人员构成上，创始人 Julian Hyde（2251 次贡献）仍是核心，但已形成去中心化的贡献群体：xiedeyantu、mihaibudiu、zabetak、NobiGo、asolimando、silundong 等多人长期活跃，2025 年 12 月还新增了 3 位 committer。

⚠️ 关键判断：**没有单一商业厂商主导**这一点被社区分析者认为是 Calcite 长期健康的关键——它不像某些项目会被一家公司的战略转向拖垮。

### 架构定位：三层结构，明确"不做执行"边界

Calcite 官方自我定位是"The foundation for your next high-performance database"，提供三件事：标准 SQL 解析器与 JDBC 驱动、基于关系代数的查询优化、连接第三方数据源的适配器。

它有两个子项目：Avatica（JDBC/ODBC 驱动框架，与 Arrow Flight SQL、ADBC 竞争）和 Enumerable（编译式查询执行引擎，与 Velox、DataFusion 竞争）。

这里有一个关键判断：**Enumerable 是 Calcite 的软肋**。社区分析者直言"Apache Calcite has very advanced query optimization but weak execution"——它的优化器很强，但执行层无法与向量化引擎竞争。这决定了 Calcite 在"全栈性能竞赛"中天然处于劣势。

### 近年技术演进：优化器深度和方言广度两条线

从 1.36 到 1.42 的发布亮点能清楚看到 Calcite 的发力方向：

- **优化器深度**：1.39 引入基于动态规划的 DPhyp 最优连接枚举算法、INTERSECT→semi-join、MINUS→anti-join 改写规则、复杂连接条件下的谓词扩展；1.40 进一步增强集合操作优化与 UNION 同源去重。这些都是优化器理论的前沿落地。
- **方言广度**：1.37 加入 StarRocks 方言（CALCITE-6257）和 Apache Arrow 适配器；1.40 加入 Doris、DuckDB、SQLite、Trino 方言并改进 ClickHouse 支持。这是极具战略意味的动作——下文展开。

## 新一代框架为何集体绕开 Calcite

### 竞争格局：六款主流引擎，零采用 Calcite

把六款新一代查询框架摆在一起，结论非常刺眼：**没有一款使用 Calcite**。

- **StarRocks**：MPP 架构（大规模并行处理，多节点并行执行查询的架构），Frontend（FE）负责 SQL 解析与计划、Backend（BE）执行，CBO + 全向量化执行 + 列式存储 + 物化视图透明改写，完全自研 SQL 全栈。
- **DuckDB**：嵌入式分析数据库，C++ 实现，进程内向量化执行 + 列式存储 + ACID，PostgreSQL 兼容 SQL，自研解析器。
- **DataFusion**：Rust 向量化查询引擎框架，**使用 `sqlparser-rs` 而非 Calcite** 解析 SQL，自建 LogicalPlan/ExecutionPlan 全链路。
- **Trino/Presto**：分布式联邦 MPP，coordinator-worker 架构，自研 SQL 解析与优化。
- **ClickHouse**：列式存储 + 向量化执行，极致 OLAP 性能，自研 SQL。
- **Spark SQL**：大规模分布式 SQL，自研 Catalyst 优化器 + AQE 适应性执行。

### 根本原因：紧耦合才能榨取极限性能

新框架不选 Calcite，不是因为"不了解"或"集成难"——根本原因是**现代 OLAP 性能的护城河来自优化器与执行器的协同设计**。

SIGMOD 2024 的 DataFusion 论文点破了这一点："in real products, there are no clear boundaries between query optimization and query execution"——好的优化器要简化表达式就需要执行器配合，执行器要在运行时收集统计反馈再优化计划，二者必须紧耦合。

Calcite 的哲学恰好相反：**把优化器做成可插拔的中间件**。这种解耦在"快速搭建能用的系统"时是优势，但在追求极致性能时变成负担——你需要跨越 JVM/Native 边界、对接两套内存模型、在不能改执行器的前提下做优化假设。

Querifylabs 的分析很直白："maintaining a good query engine and query optimizer in the same project is twice as hard as maintaining one of them"，但现实是**主流高性能引擎都选择了 twice as hard 的全栈自研**。

### DataFusion 特例：另一种可组合实现

DataFusion 是这个格局中的一个特例。它和 Calcite 一样走"可组合"路线，但实现路径完全不同：Rust 原生、Arrow 内存格式、向量化执行、`sqlparser-rs` 解析。

SIGMOD 2024 论文的核心论点是"open standards and extensible design do not preclude state-of-the-art performance"——DataFusion 在多个 benchmark 上接近 DuckDB，证明了模块化设计不必然牺牲性能。

⚠️ 但要注意：**DataFusion 不是 Calcite 的替代品，而是另一种可组合实现**。Calcite 强在优化器、弱在执行；DataFusion 强在执行、弱在优化器。二者在"可组合数据系统"谱系上是互补关系而非替代关系。把 DataFusion 描述成"基于 Calcite"是事实错误——它从头到尾是 Rust 自研链路。

## 优化器理论前沿：Cascades、学习型与适应性

Calcite 的生命力很大程度上取决于"优化器"这件事本身是否还在演进、是否还有独立价值。从理论前沿看，答案是肯定的——而且方向比"传统 CBO"丰富得多。

### Cascades：Calcite TopDownRuleDriver 的理论源头

Goetz Graefe 1995 年的 Cascades 框架是现代顶级优化器的共同祖先：Microsoft SQL Server、Greenplum Orca 都基于它，Calcite 的 `TopDownRuleDriver` 也是其实现。

Cascades 相比 Volcano 的关键改进是：把优化拆成任务对象（task as data structure）、用规则插入 property enforcer、按"promise"动态排序任务、逻辑/物理规则统一表示。

CMU 15-799（2025 Spring）讲义指出，Cascades 的四 ideas 仍是现代优化器的核心：任务化、enforcer 规则化、promise 排序、规则算子统一。这意味着 **Calcite 在优化器骨架上并没有落后**——它用的是和 SQL Server 同源的理论框架。

问题在于骨架对了不等于肌肉够强：Cascades 论文里的多阶段优化（Simplification→Pre-Exploration→Exploration→Post-optimization）、并行搜索（Orca 实现）、精确 cardinality 估计反馈，这些 Calcite 都有不同程度的缺失或薄弱。

### Neo：端到端学习型优化器的挑战

Ryan Marcus 等人 2019 年的 Neo 是第一个**端到端用机器学习替换传统优化器所有组件**的系统：查询用特征表示而非算子树、代价模型用 DNN 而非手工公式、搜索用 DNN 引导的 best-first 而非枚举/DP、cardinality 估计用 word2vec row vector 而非直方图。

Neo 在 JOB benchmark 上比 PostgreSQL 优化器快 5.6×–6.7×，证明了学习型优化的潜力。

但 Neo 至今没有大规模工业落地，原因是它的根本限制：**需要代表性样本工作负载 + 离线训练 + 持续再训练**，且泛化到未见过的查询模式是开放问题。

📌 对 Calcite 的启示是：学习型优化器短期内不会取代规则/代价驱动的主流路线，但"用 ML 辅助 cardinality 估计"和"用学习指导规则排序"是更现实的渐进方向。

### AQP：简单适应性技术往往胜过复杂学习

更值得注意的发现是：**简单的适应性查询处理（AQP）在很多时候能匹敌甚至超过学习型优化器**。

NSF 资助的研究表明，仅用 LIP（Lookahead Information Passing，半连接 + 布隆过滤器下推）+ AJA（Adaptive Join Algorithm，运行时切换 hash/nested-loop join）两项简单技术，在 JOB-Slow 工作负载上比 PostgreSQL 快 2.0×，而学习型 Balsa 和 Bao 只快 1.4×。

AQORA（2025）进一步把 LQO（学习型优化）和 AQP（适应性执行）结合，在 Spark SQL 上比学习型方法减少 90% 执行时间、比默认 AQE 减少 70%。Spark SQL 3.0 的 AQE 本身就是 AQP 的工业实现：推迟 join 策略决定、按 shuffle 分区大小重优化、合并小分区、修复倾斜 join。

⚠️ 这对 Calcite 的判断很关键：**优化器的未来不是"更复杂的离线 CBO"，而是"运行时反馈 + 适应性调整"**。而 Calcite 恰恰没有执行层——它无法在执行中收集真实 cardinality、无法做运行时重优化。这是它的结构性短板。

## Calcite 定位过时了吗

### 优化器框架在全栈自研时代还有价值吗

有，但价值区间收窄了。从 Calcite 的实际采用方看，它仍服务于三类不可替代的场景：

1. **流式 SQL**：Flink 用 Calcite 解析流式与批式 SQL 并做查询优化，2026 年 5 月还在升级到 Calcite 1.38.0，6 月继续升 1.39.0。流式 SQL 语法标准化这件事，除 Calcite 外几乎没有替代品。
2. **联邦查询的适配器模式**：Calcite 的适配器能连接 JDBC、HBase、Elasticsearch、Geode、Arrow 等多种数据源，在"一个 SQL 查多个源"的场景仍有结构优势。
3. **方言改写**：1.37–1.40 加入 StarRocks、Doris、DuckDB、SQLite、Trino 方言，意味着 Calcite 能把一条标准 SQL 改写成各引擎的方言——这正是产品线查询服务"感知底层库直接生成该库 SQL"需要的核心能力。

但要在"高性能 OLAP 执行"场景里找 Calcite 的位置，答案是没有。StarRocks/DuckDB/ClickHouse 的性能护城河是存储+向量化+优化器协同设计，Calcite 只能提供其中三分之一，且是最容易被自研替代的三分之一。

### Flink 差点 fork Calcite 的信号

ASF 纪要里有一处值得注意的细节："an interesting discussion in both the Apache Calcite and Apache Flink communities about the pros and cons of forking Calcite by the latter"，Calcite 社区"advised against this idea, due to the elevated maintenance costs in long term"。

这说明两件事：一是 Calcite 对大型消费者（Flink）的演进节奏和定制能力已经不够用，Flink 才会认真考虑 fork；二是 fork 的长期维护成本被公认为高到不值得——这反过来证明 **Calcite 作为公共基础设施的"中位线"价值仍在**，只是天花板用户会感到受限。

### 采用方现状

从 Calcite "powered by" 页面看，采用方包括 Alibaba MaxCompute、Apache Drill、Apache Flink、Apache Hive、Apache Kylin、Apache Phoenix、Apache Samza、Apache Beam、Dremio、Feldera、OmniSci 等。其中：

- **Flink** 仍是 Calcite 最重要的使用者，2026 年持续升级版本。
- **Drill** 项目活跃度大幅下降，已非主流。
- **Phoenix** 在 Calcite 文档里仍标注"under development"，集成深度有限。
- **Hive** 与 **Kylin** 作为遗留大数据组件仍在维护期。
- **Feldera** 是 1.42 新加入"powered by"的新采用者，代表流式数据库新场景。
- 用户任务中提到的 "Blast" 在 Calcite 官方采用方页面未出现，无法核实，可能为小众或已停更项目。

净结论：**Calcite 的采用方以流式/遗留大数据为主，在新兴 OLAP 引擎中零采用**。这不是衰退信号——流式 SQL 标准化是 Calcite 的稳固阵地——但确实意味着它在"高性能分析查询"主战场被边缘化了。

## 竞争力分析：独特价值与劣势

### Calcite 的独特价值

1. **方言改写能力**：能在标准 SQL 与 StarRocks/Doris/DuckDB/ClickHouse/Trino/Spark/Oracle/PostgreSQL 等十多种方言间互译。对产品线"统一 SQL、感知底层库"的需求，这是**唯一现成的开源实现**。
2. **联邦查询适配器**：JDBC、HBase、Elasticsearch、Geode、Arrow 等适配器，配合优化器的下推决策，能实现"一个 SQL 查多个源"。Trino 用 connector 级联邦，Calcite 用 optimizer 级改写——两条路线各有适用场景。
3. **优化器即服务**：把 CBO/RBO、Volcano/Cascades 规则系统、DPhyp 连接枚举打包成可嵌入的库，新引擎不必从零写优化器。
4. **社区去中心化**：无单一厂商主导，长期可持续性高于商业引擎。

### Calcite 的劣势

1. **无向量化执行层**：Enumerable 是编译式但非向量化，无法与 Velox/DataFusion/DuckDB 的向量化执行竞争。
2. **JVM 单体进程**：跨语言集成需 JNI/IPC，与 Rust/C++ 原生引擎对接成本高。
3. **无分布式集群能力**：没有 MPP 调度、没有 shuffle、没有分布式容错——这些都要使用者自建。
4. **无运行时适应性**：缺少 AQE 式的执行中重优化，无法利用真实 cardinality 反馈。
5. **文档定位错位**：社区分析者指出 Calcite 文档导向了错误场景（端到端引擎和 JDBC），而非"可组合查询优化"，导致新用户理解成本高。

### 生命周期判断

作为"SQL 优化器中间件"，Calcite 在 5 年内仍有持续需求，需求来源是：流式 SQL 标准化（Flink 类）、联邦查询（Dremio 类）、方言互译（产品线查询服务类）。

但在"高性能 OLAP 执行引擎"赛道，它已经退出竞争——这不是预测，是已经发生的事实。它的生命力上限是"中间件"，不是"引擎"。

## 与产品线查询服务的关联

产品线查询服务的演进方向是"向语义层演进，感知底层库直接生成该库 SQL"。在这个语境下，Calcite 的价值不在"用它做执行引擎"，而在两层：

1. **方言改写层**：用 Calcite 的方言支持把语义层下发的标准 SQL 改写成 StarRocks/DuckDB/ClickHouse 等底层引擎的方言。这是 Calcite 当前最不可替代的能力——1.37–1.40 主动加入竞争对手的方言，正是看到了这个市场需求。
2. **联邦优化层**：当查询跨多个底层库时，用 Calcite 优化器做下推决策与跨源改写。但这条路线要和 Trino 的 connector 级联邦比较——Trino 在分布式执行上更强，Calcite 在改写灵活度上更强。

⚠️ 需要警惕的陷阱是：**不要把 Calcite 当作执行引擎来用**。Enumerable 跑不出向量化引擎的性能，强行用它做全栈查询会陷入"中间件性能天花板"。正确用法是"Calcite 做优化与改写，执行交给底层引擎"——这与产品线的"感知底层库"理念天然契合。

## 下一步行动

按"验证项/观察项/布局项"三层划分：

### 验证项（短期可落地）

- 用 Calcite 1.42 的方言改写能力做"标准 SQL → StarRocks/DuckDB/ClickHouse 方言"的自动转换，验证在产品线查询服务中的改写准确率与覆盖面。
- 评估 Calcite 的 Arrow 适配器能否对接向量化执行后端（DataFusion/Velox），形成"Calcite 优化 + 向量化执行"的混合栈。

### 观察项（中期跟踪）

- 跟踪 Flink 升级 Calcite 的节奏与 fork 讨论——若 Flink 真的 fork，意味着 Calcite 公共版本可能失去最大贡献者，需重新评估依赖风险。
- 跟踪 DataFusion 优化器的演进——若其优化器能力追上 Calcite，"Rust 全栈可组合"将直接威胁 Calcite 的"优化器即服务"定位。
- 跟踪学习型优化器（Neo/Balsa/AQORA）的工业落地节奏，判断是否需要在 Calcite 之上叠加 ML 辅助 cardinality 估计。

### 布局项（长期方向）

- 探索"Calcite 优化器 + DataFusion/Velox 执行器"的混合架构，规避 Calcite 无向量化执行的短板，同时保留其方言与联邦能力。
- 探索 Calcite 与语义层（LookML/Cube/MetricFlow）的结合——语义层产出标准 SQL，Calcite 改写成方言，底层引擎执行，形成"语义层→Calcite→多引擎"的三段式。
- 评估近似查询与采样优化在产品线的适用性——AQP 的简单技术（LIP/AJA）往往比复杂学习更实用，可作为 Calcite 优化器的补充规则。

## 参考链接

- [Apache Calcite 董事会会议纪要（ASF Whimsy）](https://whimsy.apache.org/board/minutes/Calcite.html)
- [Apache Calcite Releases 页面](https://calcite.apache.org/news/releases/)
- [Composable Data Systems: Lessons from Apache Calcite Success（Querifylabs）](https://www.querifylabs.com/blog/composable-data-systems-lessons-from-apache-calcite-success)
- [Lakehouse Query Engines: Trino vs StarRocks vs DuckDB](https://aicodeinvest.com/lakehouse-query-engines-trino-starrocks-duckdb-comparison/)
- [Apache Arrow DataFusion: a Fast, Embeddable, Modular Analytic Query Engine（SIGMOD 2024）](https://andrew.nerdnetworks.org/other/SIGMOD-2024-lamb.pdf)
- [Apache DataFusion 官方文档](https://datafusion.apache.org/)
- [Apache Calcite Powered By 列表](https://calcite.apache.org/docs/powered_by.html)
- [Apache Calcite 官方站点](https://calcite.apache.org/)
- [Apache Calcite History（贡献者与发布亮点）](https://calcite.apache.org/docs/history.html)
- [StarRocks 架构文档](https://docs.starrocks.io/docs/introduction/Architecture/)
- [Apache DataFusion vs DuckDB（Spice.ai）](https://spice.ai/learn/apache-datafusion-vs-duckdb)
- [DuckDB 官方站点](https://duckdb.org/)
- [ClickHouse 官方文档](https://clickhouse.com/docs)
- [Apache Spark SQL Adaptive Query Execution 文档](https://spark.apache.org/docs/latest/sql-performance-tuning.html)
- [The Cascades Framework for Query Optimization（Graefe 1995, IEEE Data Engineering Bulletin）](https://15721.courses.cs.cmu.edu/spring2016/papers/graefe-ieee1995.pdf)
- [CMU 15-799 Query Optimization, Spring 2025 — Cascades Lecture Notes](https://15799.courses.cs.cmu.edu/spring2025/notes/05-cascades.pdf)
- [The Cascades Framework for Query Optimization at Microsoft（UW CSEP590D Lecture）](https://courses.cs.washington.edu/courses/csep590d/22sp/lectures/CascadesUW.pdf)
- [Neo: A Learned Query Optimizer（VLDB 2019, Marcus et al.）](https://arxiv.org/pdf/1904.03711)
- [Neo: A Learned Query Optimizer（VLDB Proceedings）](https://www.vldb.org/pvldb/vol12/p1705-marcus.pdf)
- [Simple Adaptive Query Processing vs. Learned Query Optimizers（NSF PAR）](https://par.nsf.gov/servlets/purl/10480096)
- [AQORA: A Learned Adaptive Query Optimizer for Spark SQL（arXiv 2025）](https://arxiv.org/html/2510.10580v1)
- [FLINK-36602: Upgrade Calcite version to 1.38.0（Apache Flink PR #28170）](https://github.com/apache/flink/pull/28170)
- [Apache Flink Calcite 1.39.0 Upgrade PR #28290](https://github.com/apache/flink/pull/28290)
- [Apache Calcite powered_by 源（GitHub）](https://github.com/apache/calcite/blob/main/site/_docs/powered_by.md)

## ✅ 总结

### 定位必须清晰：中间件而非引擎

Calcite 是"SQL 优化器与方言改写中间件"，不是"查询引擎"。当中间件用，在流式 SQL、联邦查询、方言互译三个场景 5 年内仍不可替代；当引擎用，它已经输给 StarRocks/DuckDB/ClickHouse。

产品线查询服务的正确用法是"Calcite 做改写与优化，执行交给底层引擎"。

### 绕开 Calcite 不是 Calcite 的失败

优化器与执行器紧耦合才能榨取极限性能，这是 OLAP 引擎的护城河。Calcite 的"可组合"哲学与"紧耦合"现实存在根本张力——这不会因为 Calcite 变强而改变。

DataFusion 走的是另一条"可组合但 Rust 原生向量化"路线。它证明可组合不必然牺牲性能，但也证明"不用 Calcite 一样能做可组合优化器"。

### 发力空间在嵌入式优化器即服务

1.37–1.40 主动加入竞争对手方言是正确战略。下一步应该做三件事：

- 把优化器做成可被 Rust/C++ 引擎通过 IPC/FFI 调用的服务
- 补强运行时适应性（AQP）
- 与语义层深度集成

若能做到这些，Calcite 在"多引擎联邦 + 语义层"场景的生命力会延续 5 年以上。若继续在 Enumerable 执行层投入，则是与 Velox/DataFusion 打一场必败的仗。
