# 自动驾驶 E2E / Planning / Parking / VLA 论文库

本库面向已有模块化自动驾驶经验、正在从传统规划/泊车转向 AI、E2E 与 VLA 的工程师。它不是热门论文排行榜，而是围绕 **planner 的系统角色、action representation 与评价证据** 组织的可执行阅读库。

当前版本收录 65 篇需精读或专题深读的论文：A 级 25 篇，B 级 40 篇，共约 441 MB。另有 C 级候选仅记录在 [draft_selection.md](../draft_selection.md)，未下载 PDF。

## 目录结构

```text
papers/
├── A_core/                         # 25 篇领域主干，按 A 级内部编号命名
├── B_topic/
│   ├── planning_foundations/       # 1
│   ├── e2e_driving/                # 6
│   ├── world_model_rl/              # 7
│   ├── parking/                    # 10
│   ├── diffusion_planning/         # 6
│   ├── action_representation/      # 3
│   ├── driving_vla/                # 7
│   └── benchmarks/                 # 当前为空；四篇 benchmark 均列为 A
├── metadata/
│   ├── papers.csv                  # 结构化元数据、全局阅读序号与本地路径
│   └── review_audit.json           # PDF 页数、文本提取与章节抽查记录
└── README.md
```

库外的两份主文档：

- [reading_order.md](../reading_order.md)：按知识依赖组织的完整学习路线，以及两周 12 篇清单。
- [research_landscape.md](../research_landscape.md)：主干与泊车子线、VLA 分层、benchmark 证据强度和研究空白。

## 分级标准

### A 级：必须精读

满足至少一项：定义重要范式或 benchmark；显著影响后续工作；提供当前 E2E/VLA driving 的代表性强基线；不读会妨碍理解领域演进。A 级严格控制为 25 篇。

### B 级：特定方向值得深入

不是全领域共同主干，但对 parking、action representation、diffusion/flow planning、world model/RL、language–action alignment 等具体研究问题有直接方法或工程价值。当前 40 篇。

### C 级：知道贡献即可

跟进、工程组合、小幅改进，或虽名称相关但系统角色不属于核心 planner/VLA。C 级没有下载，原因和代表性候选见 [draft_selection.md](../draft_selection.md)。例如 ParkDiffusion 的主体更接近停车场交通参与者轨迹预测，不能仅凭名字当作 ego parking planner。

分级不机械依赖 citation。元数据中的 influence_signal 将社区影响、方法创新、工程价值和 benchmark 地位分开描述；2025–2026 年论文以问题定义、公开评测与路线代表性为主，不用低引用数惩罚新工作。

## A 级论文与推荐位置

下面编号是 A 级文件编号；真正的全局阅读序号包含 B 级桥接论文，以 [papers.csv](metadata/papers.csv) 的 reading_order 为准。

1. [ChauffeurNet](A_core/01_ChauffeurNet_2019.pdf) — 行为克隆分布偏移与合成扰动/恢复。
2. [Learning by Cheating](A_core/02_Learning_by_Cheating_2020.pdf) — 特权教师到传感器学生。
3. [nuPlan](A_core/03_nuPlan_2021.pdf) — 闭环 ML planning benchmark。
4. [TransFuser](A_core/04_TransFuser_2023.pdf) — 多传感器 Transformer E2E 基线。
5. [TCP](A_core/05_TCP_2022.pdf) — trajectory-guided control 双分支。
6. [PlanT](A_core/06_PlanT_2022.pdf) — object-level planning transformer。
7. [ST-P3](A_core/07_ST-P3_2022.pdf) — BEV perception/prediction/planning 过渡。
8. [UniAD](A_core/08_UniAD_2023.pdf) — planning-oriented unified stack。
9. [VAD](A_core/09_VAD_2023.pdf) — vectorized scene 与高效端到端规划。
10. [Bench2Drive](A_core/10_Bench2Drive_2024.pdf) — CARLA 多能力闭环 E2E benchmark。
11. [NAVSIM](A_core/11_NAVSIM_2024.pdf) — data-driven non-reactive planning evaluation。
12. [WOD-E2E](A_core/12_WOD-E2E_2025.pdf) — 真实长尾端到端驾驶 benchmark。
13. [Behavior Transformers](A_core/13_Behavior_Transformers_2022.pdf) — 离散行为模式 + 连续残差。
14. [Diffusion Policy](A_core/14_Diffusion_Policy_2023.pdf) — action diffusion 的通用基础。
15. [VADv2](A_core/15_VADv2_2026.pdf) — vectorized E2E 中的概率规划。
16. [Diffusion-Based Planning](A_core/16_Diffusion_Planner_2025.pdf) — flexible guidance 与结构化轨迹生成。
17. [DiffusionDrive](A_core/17_DiffusionDrive_2025.pdf) — 面向实时 E2E 的 truncated diffusion。
18. [LMDrive](A_core/18_LMDrive_2024.pdf) — 语言指令条件下的闭环端到端驾驶。
19. [DriveVLM](A_core/19_DriveVLM_2024.pdf) — 语言高层决策连接 trajectory planner。
20. [SimLingo](A_core/20_SimLingo_2025.pdf) — vision-only closed-loop language–action alignment。
21. [AutoVLA](A_core/21_AutoVLA_2025.pdf) — 自适应推理与强化微调的 VLA。
22. [ReCogDrive](A_core/22_ReCogDrive_2026.pdf) — 认知先验与 diffusion planner 结合。
23. [Poutine](A_core/23_Poutine_2025.pdf) — vision-language-trajectory 预训练与 RL 后训练。
24. [EMMA](A_core/24_EMMA_2025.pdf) — 统一多模态模型与文本化 waypoint/action 表示。
25. [DriveMA](A_core/25_DriveMA_2026.pdf) — 可验证 meta-action 缩小 language–action gap。

## 各方向的核心入口

| 方向 | 第一组应读 | 第二组专题深化 |
|---|---|---|
| 传统 BC → E2E | ChauffeurNet、LBC、TransFuser、TCP | Deep Imitative Models、NEAT、ThinkTwice |
| Unified perception–prediction–planning | ST-P3、UniAD、VAD | DriveAdapter、PPAD、DriveTransformer、Hydra-MDP |
| Closed-loop evaluation | nuPlan、Bench2Drive、NAVSIM、WOD-E2E | 阅读各 benchmark devkit/metric 实现 |
| Action representation | Behavior Transformers、Diffusion Policy | VQ-BeT、ACT、Trajectory Transformer |
| Diffusion / flow planning | Diffusion Planner、DiffusionDrive、VADv2 | Diffusion-ES、GoalFlow、GuideFlow、WAM-Flow、PlannerRFT |
| World model / RL | GenAD、LAW、WoTE | Think2Drive、Doe-1、RAD、Raw2Drive |
| Parking E2E | ParkingE2E、ParkFormer、SunnyParking、YUKUIv2 | E2E Parking、TransParking、CAA、ParkingWorld、ParkingTransformer |
| Driving VLM → VLA | LMDrive、DriveVLM、SimLingo、DriveMA | EMMA、AutoVLA、ReCogDrive、Poutine、NoRD、LinkVLA |

## 对“泊车规划 → AI/E2E/VLA”的优先建议

最优先不是把 LLM 直接接在 steering 上，而是按以下接口理解与复现：

1. 用 VAD/UniAD 理解 scene representation 与 planning query 如何连接；
2. 用 Behavior Transformers/VQ-BeT 理解多模态行为与离散 action code；
3. 用 ParkingE2E 建立 image/goal → trajectory 的可运行基线；
4. 用 SunnyParking 把 multi-shot 与 motion state 显式化；
5. 用 YUKUIv2 学习 key-point + diffusion 连续生成；
6. 用 DriveMA 思考可验证 meta-action，例如 gear、maneuver intent、subgoal 与 termination；
7. 保留传统运动学投影/controller 作为硬约束与安全执行层。

最值得复现的三档项目：

- **最小工程闭环**：ParkingE2E + 传统 controller，先复现闭环成功率与轨迹可行性。
- **研究型增强**：SunnyParking/YUKUIv2，对比纯回归、key-point、motion-state 和 diffusion。
- **前沿课题**：DriveMA-style maneuver token + key-point/diffusion trajectory decoder，加入语言干预测试与闭环验证。

## VLM 与 VLA 的边界

本库没有把 VQA 自动算作 VLA：

- DriveLM 是重要的 graph VQA/推理基线，但核心不输出可执行 trajectory/control。
- DriveMLM 偏 behavioral planning state/high-level interface。
- DriveVLM、ORION、ReCogDrive 的语言/推理模块会进入或修正轨迹生成，属于层级 VLA/planner enhancement。
- LMDrive、SimLingo、AutoVLA、Poutine、NoRD、LinkVLA、DriveMA 更接近联合 action/trajectory generation。

评价 VLA 时，至少检查 language intervention、rationale ablation、action grounding、closed-loop、完整 inference latency。只展示解释文本或问答准确率，不足以证明 language–action alignment。

## 元数据说明

[papers.csv](metadata/papers.csv) 共 23 个字段，其中必备字段包括：

```text
tier, reading_order, title, authors, year, venue, category,
paper_url, code_url, project_url, local_pdf, closed_loop,
action_type, reason_for_selection, notes
```

另补充 id、system_role、real_trajectory_or_action、influence_signal、reproduce_priority、pages、reviewed_sections、review_gaps。`local_pdf` 使用相对库根目录路径，便于移动整个文件夹。空的 code_url/project_url 表示调研时未找到可信官方入口，不代表代码一定不存在。

`closed_loop` 是分级标签而非单一布尔真值；具体可能是 CARLA、nuPlan、NAVSIM non-reactive、其他仿真或实车。比较论文前请阅读 notes。

## PDF 来源与校验

下载遵循：正式会议/期刊 open access 或最新 arXiv，其次作者/项目官方页面；未使用来源不明的镜像。存在正式版时优先正式元数据，例如 EMMA 标注为 TMLR 2025、DriveMLM 标注为 Visual Intelligence 2025、ReCogDrive 使用 ICLR 2026 官方版。

所有 65 个 PDF 已完成：

- PDF magic/header 与最小文件大小检查；
- 页数和文本可提取性检查；
- abstract、introduction、method、results、ablation、limitations 的章节定位审计；
- 代表性架构页渲染抽查。

`review_gaps` 里的缺项常由扫描/双栏提取或不同章节命名造成，也可能表示 benchmark 论文确实没有传统 ablation；它是复核提示，不是自动质量判定。调研结论基于全文关键章节和图表抽查，正式复现前仍应逐表核对实验协议与代码版本。

## 两周入口

如果只有两周，只读：TransFuser、UniAD、VAD、NAVSIM、Behavior Transformers、Diffusion-Based Planning、DiffusionDrive、DriveVLM、SimLingo、SunnyParking、YUKUIv2、DriveMA。具体逐日安排和替换方案见 [reading_order.md](../reading_order.md#四两周只读-12-篇)。
