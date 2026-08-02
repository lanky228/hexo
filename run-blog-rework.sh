#!/bin/bash
export PATH="/root/.cargo/bin:/root/.local/bin:$PATH"
cd /root/workspace/hexo-blog

opcode=$(cat <<'PROMPT'
你是博客编辑。重新打磨所有博客文章，特别是早期简短的。

## 步骤
1. 读 AGENTS.md 获取写作规范（手机阅读友好、排版规则）
2. 读 source/_posts/ 下所有 .md 文件，用 `wc -l` 统计行数
3. 对每篇博客：
   a. 识别薄弱点：信息密度低/缺原创观点/结构散/过短
   b. 重新洞察：补充原创分析、数据判断、个人观点
   c. 按AGENTS.md手机阅读规范重写
   d. 保留front matter的title和date，更新tags
4. 特别关注行数<100的短博客（宇称不守恒23行、量子力学59行、狭义相对论90行等）
5. 每篇打磨后直接覆盖原文件
6. 全部完成后执行: git add -A && git commit -m "blog: 全面重打磨-重新洞察发布" && git push origin master
7. 然后部署: npx hexo clean && npx hexo generate && npx hexo deploy
8. 写结果到 BLOG-REWORK-RESULT.md

## 写作要求
- 精简，不大段引用他人
- 必须有原创观点和洞察
- 每篇开头加 💡 一句话总结
- 段落≤4行，标题用##/###
- 专业术语首次出现加括号解释
- 去掉[[E1]]等引用标记和编号前缀

## 文章列表（按行数排序，短的优先）
- 宇称不守恒.md (23行)
- 地下城堡2-暗影刺客赫芬琳.md (39行)
- 广义相对论.md (39行)
- 中国银行原油宝事件.md (42行)
- 读书笔记-开发者测试.md (43行)
- 孙杨抗检事件.md (52行)
- 量子力学.md (59行)
- 终极社会主义AI猜想.md (89行)
- 狭义相对论.md (90行)
- blog-article-universal-dividend.md (103行)
- 从中证500指数增强看中国金融业的方法论与本质.md (114行)
- 读书笔记-异常处理的设计与重构.md (137行)
- 基于统一SQL的大模型友好查询洞察分享.md (149行)
- 以及所有 Apache/DuckDB/ClickHouse 等技术洞察文章

全部都要打磨，不要遗漏。
PROMPT
)

nice -n 10 ionice -c 3 opencode run --auto "$opcode" 2>&1 | tee BLOG-REWORK-run.log
echo "BLOG_REWORK_DONE"
