---
title: 读书笔记 Web安全深度解析
date: 2020-04-20 00:09:37
tags: 计算机
categories: 学习
---

# Web 安全深度解析

## HTTP 代理工具

- Burp Suite Proxy
- Fiddler
- WinsockExpert

## 搜索引擎 site 命令

- site：域名
- intext：正文关键字
- intitle：标题关键字
- info：基本信息
- inurl：URL 关键字
- filetype：文件类型

## 信息探测工具

- Nmap
- DirBuster

## 漏洞扫描工具

- Burp Suite
- AWVS
- AppScan

## SQL 注入漏洞

### 原理

用户输入被 SQL 执行器执行。

### 分类

- 数字型注入
- 字符型注入

### 注入工具

- SQLMap
- MySQL
- Oracle

### 防御措施

- 数据类型校验
- 特殊字符转义
- 预编译语句
- 框架技术
- 存储过程

## 上传漏洞

### 原理

- IIS 解析漏洞
- Apache 解析漏洞
- PHP CGI 解析漏洞

### 防御措施

- 客户端检测

绕过方法：FireBug、中间人攻击。

- 服务端检测

方法：白名单和黑名单校验、MIME 校验、目录校验。

绕过方法：截断上传攻击。

### 文本编辑器上传漏洞

- 敏感信息暴露
- 黑名单策略错误
- 任意文件上传漏洞

原因：目录过滤不严、文件未重命名。

解决措施：接受文件保存在临时路径、白名单校验扩展名、文件重命名。

## XSS 跨站脚本漏洞

### 原理

网页嵌入恶意脚本。

### 分类

- 反射型
- 存储型
- DOM 型

### 检查工具

- AppScan
- AWVS
- Burp Suite

### XSS 危害

- XSS 会话劫持
- XSS Framework
- XSS GetShell
- XSS 蠕虫

### 防御措施

- 输入输出校验转码
- HttpOnly

## 命令执行漏洞

### 分类

- 模型漏洞

PHP、Java。

- 框架漏洞

Struts2、ThinkPHP。

### 防御措施

- 避免使用系统执行命令
- 参数校验转义
- 函数白名单
- PHP 中无法控制的函数不使用

## 文件包含漏洞

### 类型

- PHP 包含
- JSP 包含

### 防御措施

- 参数校验
- 路径限制
- 文件白名单
- 避免使用动态包含

## 其他漏洞

- CSRF
- 逻辑错误漏洞

绕过授权验证、密码找回逻辑漏洞、支付逻辑漏洞、指定账户恶意攻击。

- 代码注入

XML 注入、XPath 注入、JSON 注入、HTTP Parameter Pollution。

- URL 跳转与钓鱼
- WebServer 远程部署

Tomcat、Jboss、WebLogic。

## 常见防御措施

- 0day 漏洞修复
- 前后台安全框架
- 三方件、加密算法安全
- 数据库安全
- 安全扫描与评估

## 常见攻击

### 账户暴力破解

### 旁注攻击

- IP 逆向查询
- SQL 跨库查询
- 目录越权

防御措施：CDN。

## 提权

- 溢出提权
- 三方件提权
- 虚拟主机提权

### 攻击方法

- 3389 端口
- 端口转发
- 启动项提权
- DLL 劫持
- 提权后门

### 防御措施

- 服务器补丁
- 关闭危险端口
- 删除敏感可执行文件
- 删除不安全组件
- 安装安全配置软件

## ARP 欺骗攻击

### 检查工具

- Cain
- Ettercap
- NetFuke

### 防御措施

- 静态绑定
- ARP 防火墙

## 社会工程学

- 信息收集
- 沟通
- 伪造
