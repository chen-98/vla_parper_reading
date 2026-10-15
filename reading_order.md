# 自动驾驶 E2E / Planning / Parking / VLA 推荐学习路线

这条路线不是按发表年份排队，而是按“问题定义 → 表示方式 → 训练方法 → 闭环验证 → 语言与动作对齐”的依赖关系组织。你的模块化规划背景已经足够，因此不再从感知或 Transformer 基础讲起，直接围绕 planner 如何被学习系统替换、增强或重新定义展开。

完整分级见 [draft_selection.md](draft_selection.md)，论文元数据与本地路径见 [papers.csv](papers/metadata/papers.csv)。

## 一、先建立三个判断坐标

阅读每篇论文时，先回答三个问题：

1. 它替换的是完整 planner、候选轨迹打分器，还是仅高层决策接口？
2. 最终动作是什么：连续轨迹、低层控制、离散 action token、meta-action，还是生成分布？
3. 主要证据来自 open-loop imitation、non-reactive simulation、reactive closed-loop，还是实车？

如果这三个问题没有分清，“E2E”“VLA”“world model”这些标签会把完全不同的系统混在一起。

## 二、推荐阅读阶段

### 阶段 1：模仿学习与可恢复性

核心顺序：

1. [ChauffeurNet](papers/A_core/01_ChauffeurNet_2019.pdf)
2. [Deep Imitative Models](papers/B_topic/planning_foundations/B01_Deep_Imitative_Models_2020.pdf)
3. [Learning by Cheating](papers/A_core/02_Learning_by_Cheating_2020.pdf)

先读这一组，是为了建立后面所有方法都绕不开的三个问题：行为克隆的分布偏移、多模态轨迹分布，以及特权信息如何作为训练教师。ChauffeurNet 用合成扰动暴露“只拟合专家轨迹”为什么不够；Deep Imitative Models 把规划写成可条件化的轨迹概率推断；Learning by Cheating 则形成 privileged teacher → sensor student 的经典范式。

继承关系：ChauffeurNet 的 perturbation/recovery 思想会在闭环数据增强、RL post-training 中反复出现；Deep Imitative Models 是 diffusion/flow trajectory distribution 的概念前身之一；LBC 的教师—学生思路影响了大量 CARLA E2E 工作。

### 阶段 2：从原始传感器到轨迹/控制

核心顺序：

1. [TransFuser](papers/A_core/04_TransFuser_2023.pdf)
2. [NEAT](papers/B_topic/e2e_driving/B02_NEAT_2021.pdf)
3. [TCP](papers/A_core/05_TCP_2022.pdf)
4. [PlanT](papers/A_core/06_PlanT_2022.pdf)
5. [ThinkTwice](papers/B_topic/e2e_driving/B03_ThinkTwice_2023.pdf)

TransFuser 是 raw sensor fusion E2E 的主干基线；TCP 用 trajectory branch 与 control branch 相互约束，适合规划工程师理解“轨迹监督如何帮助控制”；PlanT 则转向 object-level tokens，可解释但依赖结构化感知；NEAT 和 ThinkTwice 分别代表隐式场景表征与粗到细解码。

这些是平行表示路线，不应理解成简单迭代：

- TransFuser/TCP：图像或传感器特征直接驱动轨迹/控制。
- PlanT：先把世界变成对象 token，再做规划。
- NEAT：用神经场承载几何和注意力。
- ThinkTwice：重点是更强的 planning decoder，而不是重新定义整条系统。

### 阶段 3：统一感知—预测—规划

核心顺序：

1. [ST-P3](papers/A_core/07_ST-P3_2022.pdf)
2. [UniAD](papers/A_core/08_UniAD_2023.pdf)
3. [VAD](papers/A_core/09_VAD_2023.pdf)
4. [DriveAdapter](papers/B_topic/e2e_driving/B04_DriveAdapter_2023.pdf)
5. [PPAD](papers/B_topic/e2e_driving/B05_PPAD_2024.pdf)
6. [DriveTransformer](papers/B_topic/e2e_driving/B06_DriveTransformer_2025.pdf)
7. [Hydra-MDP](papers/B_topic/e2e_driving/B07_Hydra-MDP_2024.pdf)

ST-P3 是 BEV perception/prediction/planning 的关键过渡；UniAD 用 planning query 串起 tracking、mapping、motion prediction 和 planning，定义了“planning-oriented unified stack”；VAD 用 vectorized scene/agent representation 换取更轻、更接近规划结构的接口。

后四篇不是“比 UniAD 更统一”这么简单：DriveAdapter 研究模块耦合与迁移，PPAD 强化 prediction–planning 迭代，DriveTransformer 关心可扩展统一架构，Hydra-MDP 关心多模态计划的蒸馏。它们分别是 planner enhancement、interaction modeling、scaling 和 multimodal supervision。

### 阶段 4：把评价体系放到方法之前

核心顺序：

1. [nuPlan](papers/A_core/03_nuPlan_2021.pdf)
2. [Bench2Drive](papers/A_core/10_Bench2Drive_2024.pdf)
3. [NAVSIM](papers/A_core/11_NAVSIM_2024.pdf)
4. [WOD-E2E](papers/A_core/12_WOD-E2E_2025.pdf)

把这一组放在 generative planning 和 VLA 之前，是为了避免用 open-loop L2 误判 planner。nuPlan 提供闭环规划 benchmark；Bench2Drive 在 CARLA 中拆解多能力闭环场景；NAVSIM 用 non-reactive simulation 与 PDMS 提供低成本快速迭代；WOD-E2E 强调真实数据、长尾场景和更严格的端到端评测。

关键区别：

| Benchmark | 主要性质 | 最适合回答 | 不能单独证明 |
|---|---|---|---|
| nuPlan | log replay + closed-loop planner simulation | 规划舒适性、安全、进度 | raw-sensor E2E 感知能力 |
| Bench2Drive | CARLA reactive closed-loop | 多能力端到端闭环鲁棒性 | 真实世界泛化 |
| NAVSIM | data-driven non-reactive simulation | 快速迭代与统一 planning score | 对其他交通参与者的交互因果性 |
| WOD-E2E | 真实数据长尾 E2E benchmark | 真实分布与长尾挑战 | 完整真实世界 reactive closed-loop |

NAVSIM 的分数不能和真实闭环成功率等价；open-loop ADE/FDE 更不能代替碰撞、进度、规则与舒适性的联合评估。

### 阶段 5：动作表示与序列建模

核心顺序：

1. [Behavior Transformers](papers/A_core/13_Behavior_Transformers_2022.pdf)
2. [VQ-BeT](papers/B_topic/action_representation/B22_VQ-BeT_2024.pdf)
3. [ACT](papers/B_topic/action_representation/B23_ACT_2023.pdf)
4. [Trajectory Transformer](papers/B_topic/action_representation/B24_Trajectory_Transformer_2021.pdf)

这组主要来自机器人与 offline RL，但对泊车尤其重要。Behavior Transformer 用离散行为簇处理多模态；VQ-BeT 用残差向量量化学习 latent action code；ACT 说明 action chunking 如何减少长时域误差与推理频率；Trajectory Transformer 把状态、动作、回报都变成序列 token。

它们与 VAD/UniAD 是平行路线：前者重新设计 action space，后者主要重新设计 scene/planning representation。真正值得迁移到泊车的问题是：一个 token 应表示单帧控制、短轨迹 chunk、换挡后的 maneuver，还是“倒车入位/前进修正”这种 meta-action？

### 阶段 6：Diffusion / Flow 规划

核心顺序：

1. [Diffusion Policy](papers/A_core/14_Diffusion_Policy_2023.pdf)
2. [VADv2](papers/A_core/15_VADv2_2026.pdf)
3. [Diffusion-Based Planning with Flexible Guidance](papers/A_core/16_Diffusion_Planner_2025.pdf)
4. [Diffusion-ES](papers/B_topic/diffusion_planning/B16_Diffusion-ES_2024.pdf)
5. [DiffusionDrive](papers/A_core/17_DiffusionDrive_2025.pdf)
6. [GoalFlow](papers/B_topic/diffusion_planning/B17_GoalFlow_2025.pdf)
7. [GuideFlow](papers/B_topic/diffusion_planning/B18_GuideFlow_2026.pdf)
8. [WAM-Flow](papers/B_topic/diffusion_planning/B19_WAM-Flow_2026.pdf)
9. [PlannerRFT](papers/B_topic/diffusion_planning/B20_PlannerRFT_2026.pdf)
10. [Hyper Diffusion Planner](papers/B_topic/diffusion_planning/B21_Hyper_Diffusion_Planner_2026.pdf)

Diffusion Policy 先建立 action diffusion 的通用直觉。VADv2 把概率规划接回 vectorized E2E driving；Diffusion-Based Planning 展示 guidance/constraint 如何进入去噪；DiffusionDrive 重点解决端到端驾驶中的推理步数和延迟。后续 flow matching、reinforcement fine-tuning 与多假设生成是在“质量—速度—可约束性”三角上做不同取舍。

两条并行路线：

- Planner-level generative model：直接在结构化场景条件下生成轨迹，如 Diffusion Planner、GoalFlow、GuideFlow。
- Full E2E decoder replacement：生成模块嵌入传感器到轨迹的系统，如 VADv2、DiffusionDrive。

复现时不要只报告采样质量；至少同时测推理延迟、候选数、闭环安全、轨迹可行性与 guidance 失效模式。

### 阶段 7：World model 与 RL/post-training

核心顺序：

1. [GenAD](papers/B_topic/world_model_rl/B10_GenAD_2024.pdf)
2. [LAW](papers/B_topic/world_model_rl/B08_LAW_2025.pdf)
3. [WoTE](papers/B_topic/world_model_rl/B09_WoTE_2025.pdf)
4. [Think2Drive](papers/B_topic/world_model_rl/B13_Think2Drive_2024.pdf)
5. [Doe-1](papers/B_topic/world_model_rl/B12_Doe-1_2024.pdf)
6. [RAD](papers/B_topic/world_model_rl/B14_RAD_2025.pdf)
7. [Raw2Drive](papers/B_topic/world_model_rl/B15_Raw2Drive_2025.pdf)

GenAD/LAW 更接近“学可预测的世界表示”；WoTE 用世界模型做在线候选轨迹评价；Think2Drive/Doe-1 让 policy 在 latent world 中学习；RAD/Raw2Drive 把大规模模拟与强化学习后训练推进到 raw-sensor policy。要特别区分“预测未来世界”与“用世界模型训练/筛选 planner”，二者工程接口和失败模式不同。

### 阶段 8：泊车专线——从单段回归到 maneuver-aware 生成

核心顺序：

1. [E2E Parking](papers/B_topic/parking/B25_E2E_Parking_2024.pdf)
2. [ParkingE2E](papers/B_topic/parking/B26_ParkingE2E_2024.pdf)
3. [E2E Parking Dataset](papers/B_topic/parking/B27_E2E_Parking_Dataset_2025.pdf)
4. [TransParking](papers/B_topic/parking/B28_TransParking_2025.pdf)
5. [CAA-Policy](papers/B_topic/parking/B40_CAA-Policy_2025.pdf)
6. [ParkFormer](papers/B_topic/parking/B31_ParkFormer_2025.pdf)
7. [SunnyParking](papers/B_topic/parking/B29_SunnyParking_2026.pdf)
8. [YUKUIv2](papers/B_topic/parking/B30_YUKUIv2_2026.pdf)
9. [ParkingWorld](papers/B_topic/parking/B11_ParkingWorld_2026.pdf)
10. [ParkingTransformer](papers/B_topic/parking/B32_ParkingTransformer_2026.pdf)

E2E Parking 是视觉到控制；ParkingE2E 把输出改成轨迹，便于接现有 controller；TransParking/CAA/ParkFormer 分别改善 localization、控制注意力与 goal/pedestrian/gear-aware policy。SunnyParking 把 multi-shot 与 motion state 显式化，YUKUIv2 再把关键点与 diffusion 连续 waypoint generator 组合起来。这正是“纯 trajectory regression → 结构化 maneuver representation”的主线。

ParkingWorld 属于 RL/corrective experience 分支；ParkingTransformer 属于 LLM-enhanced trajectory planner 分支。它们都不是 SunnyParking/YUKUIv2 的直接后继。读泊车论文时统一记录：是否多把、换挡/运动状态如何表达、Ackermann/曲率约束、车位目标表示、多模态、动态障碍、闭环成功率、CARLA/实车。

### 阶段 9：从 Driving VLM 到真正的 Driving VLA

核心顺序：

1. [LMDrive](papers/A_core/18_LMDrive_2024.pdf)
2. [DriveLM](papers/B_topic/driving_vla/B33_DriveLM_2024.pdf)
3. [DriveMLM](papers/B_topic/driving_vla/B34_DriveMLM_2025.pdf)
4. [DriveVLM](papers/A_core/19_DriveVLM_2024.pdf)
5. [EMMA](papers/A_core/24_EMMA_2025.pdf)
6. [SimLingo](papers/A_core/20_SimLingo_2025.pdf)
7. [ORION](papers/B_topic/driving_vla/B35_ORION_2025.pdf)
8. [AutoVLA](papers/A_core/21_AutoVLA_2025.pdf)
9. [Drive-R1](papers/B_topic/driving_vla/B36_Drive-R1_2025.pdf)
10. [ReCogDrive](papers/A_core/22_ReCogDrive_2026.pdf)
11. [Poutine](papers/A_core/23_Poutine_2025.pdf)
12. [NoRD](papers/B_topic/driving_vla/B37_NoRD_2026.pdf)
13. [LinkVLA](papers/B_topic/driving_vla/B38_LinkVLA_2026.pdf)
14. [DriveVLA-W0](papers/B_topic/driving_vla/B39_DriveVLA-W0_2026.pdf)
15. [DriveMA](papers/A_core/25_DriveMA_2026.pdf)

LMDrive 首先证明自然语言导航与闭环控制可以连接。DriveLM 刻意放在这里作为反例边界：它主要是 graph VQA/推理数据与评测，不应因含有 driving 和 language 就归为 action-generating VLA。DriveMLM 更像把语言模型对齐到 behavioral planning states 的高层接口；DriveVLM/ORION/ReCogDrive 是语言或认知规划增强轨迹生成；EMMA/SimLingo/AutoVLA/Poutine/NoRD/LinkVLA/DriveMA 则更接近联合学习 language–action/trajectory。

阅读这组时始终追问：语言是否进入 action generation 的计算图？删掉 rationale 后动作是否变化？reasoning 是因果中间变量还是旁路解释？输出是 meta-action、轨迹文本 token、连续 waypoint 还是控制？闭环与延迟是否可接受？

## 三、容易混淆但解决的问题不同

| 名称 | 实际关注点 |
|---|---|
| DriveLM | Graph VQA 与可解释驾驶推理，核心不是低层 action generation |
| LMDrive | 语言指令条件下的闭环端到端控制 |
| DriveMLM | 将多模态 LLM 对齐到行为规划状态，偏高层决策接口 |
| DriveVLM | 层级式语言决策与 trajectory planner 结合 |
| ParkingE2E | 相机 + 车位目标到连续停车轨迹 |
| E2E Parking | 相机/车辆状态到低层控制，CARLA 闭环 |
| ParkDiffusion | 本库列为 C：核心更偏停车场轨迹预测，不等于 ego parking planner |
| Diffusion Planner | 结构化输入下的可引导轨迹生成器 |
| DiffusionDrive | 端到端驾驶中的低步数 diffusion planning decoder |
| action token | 学习或离散化的低层动作/轨迹码 |
| meta-action | 带语义、可验证的高层动作单元，仍需落到轨迹/控制 |

## 四、两周只读 12 篇

针对“传统泊车/规划 → AI/E2E/VLA”的转型，建议只精读以下 12 篇；第 13–14 天不加新论文，专门做对照表和研究假设。

| 天 | 论文 | 为什么必须在这两周内读 |
|---:|---|---|
| 1 | TransFuser | 建立 raw-sensor fusion 到 waypoint/control 的现代 E2E 基线 |
| 2 | UniAD | 理解 planning-oriented unified stack 与 task query 依赖 |
| 3 | VAD | 学习 vectorized scene/planning representation，最贴近规划接口重构 |
| 4 | NAVSIM | 建立现代 planner 评价纪律，理解 non-reactive 闭环代理的边界 |
| 5 | Behavior Transformers | 为多模态 maneuver、离散动作和长尾行为打表示基础 |
| 6 | Diffusion-Based Planning | 看清 guidance、约束和轨迹分布如何统一到生成式 planner |
| 7 | DiffusionDrive | 理解 diffusion 如何进入实时 E2E driving 以及采样延迟取舍 |
| 8 | DriveVLM | 掌握语言高层决策如何真正连接 trajectory planner |
| 9 | SimLingo | 学习闭环 language–action alignment，而非只做 VQA |
| 10 | SunnyParking | 直面 multi-shot、motion state、换挡边界和人类式停车轨迹 |
| 11 | YUKUIv2 | 学习 key-point + diffusion 对多把泊车结构化生成的价值 |
| 12 | DriveMA | 将可验证 meta-action 与低层动作连接，为 VLA-style parking 提供表示启发 |

第 13 天把 12 篇统一填入一张矩阵：输入、场景表示、规划表示、动作表示、训练目标、closed-loop、延迟、运动学约束。第 14 天只做一个研究问题：**能否用可验证 maneuver token（方向/挡位/终止条件）作为上层变量，以 key-point/diffusion 生成连续可行轨迹，并在交互式停车闭环中训练与评估？**

若更偏工程落地，可用 ParkingE2E 替换 DriveVLM；若更偏通用 benchmark，可用 WOD-E2E 替换 DriveMA，但不建议在第一轮再扩张阅读量。
