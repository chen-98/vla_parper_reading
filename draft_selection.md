# 自动驾驶 E2E / Planning / Parking / VLA 必读论文库：候选分级草案

> 状态：**阶段 1–2 草案，等待确认；尚未下载 PDF。** 资料核验截至 2026-09-15。建议规模为 **A 级 25 篇、B 级 40 篇**；C 级与观察名单不进入下一阶段批量下载。

## 0. 先说结论

这份库不把所有“用了大模型”或“名字里有 driving/VLA”的工作混成一条线。主干应当按下面五种能力演化来读：

1. **可执行的学习式 planner**：从模仿专家、扰动恢复、privileged teacher 到轨迹/控制联合输出。
2. **规划导向的统一表示**：BEV、object/vector query、perception–prediction–planning 协同。
3. **可信的规划评测**：nuPlan 的反应式闭环、Bench2Drive 的交互式 CARLA、NAVSIM 的 non-reactive rollout、WOD-E2E 的长尾人类偏好评测不能互相替代。
4. **多模态动作生成**：离散 action/trajectory token、diffusion、flow matching、world-model proposal evaluation、RL post-training。
5. **真正的 Driving VLA**：language/semantic prior 必须进入 trajectory/action generation；只做 VQA、场景描述或解释的模型只能算 VLM/高层接口。

对“泊车规划 → AI/E2E/VLA”转型，最有研究价值的断点不是把普通道路 E2E 模型搬进停车场，而是：**目标车位如何表示、正倒车/换挡如何显式建模、多次揉库如何分段、轨迹多模态与可行性如何兼得、以及语言/元动作能否成为可验证的 maneuver interface。**

## 1. 分级与判定规则

- **A：必须精读（25）**。定义范式、benchmark、planning/action representation，或是当前 E2E/VLA 强代表基线。不读会使领域演进图断裂。
- **B：专题精读（40）**。对 parking、diffusion/flow、world model、RL post-training、language–action alignment 等具体方向具有明显研究或工程价值。
- **C：知道贡献即可**。跟进、组合、小幅改进、证据尚薄，或实际任务并非 ego planning。

“影响信号”优先使用正式 venue、是否形成后续路线、是否成为公开 benchmark/base code、是否有真实闭环或实车证据。**不机械使用 citation 数量。** OpenAlex/Semantic Scholar 的公共计数接口在本轮核验时分别遇到额度/限流，因此草案不填不稳定的精确数字；确认版可在可复现快照可用时补充“来源 + 日期”的数字。

### 评测标签

- **CL-reactive**：环境参与者会响应 ego（例如 nuPlan reactive simulation）。
- **CL-interactive**：真实 simulator 中执行策略并回灌观测（例如 CARLA/Bench2Drive）。
- **NR-rollout**：基于真实日志的 non-reactive 短时 rollout（NAVSIM）；比纯 L2 open-loop 更接近规划结果，但不是严格闭环。[^navsim]
- **OL-log**：日志回放轨迹误差/碰撞代理指标。
- **Rater**：人类偏好/评分（WOD-E2E）；不是 simulator closed loop。[^wod]
- **Real**：实车闭环或道路测试。

## 2. A 级：必须精读（25 篇）

### A01 — ChauffeurNet: Learning to Drive by Imitating the Best and Synthesizing the Worst

- **作者 / 年份 / venue**：Mayank Bansal, Alex Krizhevsky, Abhijit Ogale；2019；RSS 2019。
- **链接**：[paper](https://www.roboticsproceedings.org/rss15/p31.pdf)；code：未公开；project：未确认独立页面。
- **类别 / 系统角色**：learning-based trajectory planning；**planner replacement**（输入为结构化感知结果，非 raw-sensor full E2E）。
- **一句话定位**：以 waypoint/trajectory imitation 为主体，用合成扰动、碰撞/越界/进度损失教会 planner 从偏离状态恢复。
- **输出 / action type / 评测**：真实 ego trajectory；`continuous trajectory`；闭环与实车系统证据，但公开复现条件有限。
- **影响信号**：Waymo 早期学习式规划代表；“perturb learner state + auxiliary safety losses”成为处理 covariate shift 的经典工程思想。[^chauffeur]
- **为何 A / 前后关系**：连接传统 perception→planner 与后来的 raw-sensor E2E；应先于 Learning by Cheating、TransFuser 阅读，以理解很多所谓 E2E 仍保留结构化输入/控制器。
- **复现建议**：**值得复现核心训练思想，不适合追求原系统复现**；优先复现 trajectory perturbation、off-road/collision/progress loss。

### A02 — Learning by Cheating

- **作者 / 年份 / venue**：Dian Chen, Brady Zhou, Vladlen Koltun, Philipp Krähenbühl；2020；CoRL 2020（PMLR）。
- **链接**：[paper](https://proceedings.mlr.press/v100/chen20a.html)；[code](https://github.com/dianchen96/LearningByCheating)；project：同论文页。
- **类别 / 系统角色**：privileged distillation；**planner/policy training paradigm**。
- **一句话定位**：先训练看得到 simulator ground truth 的 privileged agent，再把能力蒸馏到纯视觉 sensorimotor agent。
- **输出 / action type / 评测**：waypoint/控制链路，`hybrid`；CARLA/NoCrash **CL-interactive**。
- **影响信号**：开启 CARLA E2E 中“特权专家—感知学生”的高复用训练范式，后续 TransFuser/PlanT/DriveAdapter 等均沿用或回应这一思想。[^lbc]
- **为何 A / 前后关系**：它解释了为什么“端到端部署”并不等于“端到端监督”；是理解 teacher、expert feature distillation 与 RL expert 的前置论文。
- **复现建议**：**高**；代码与 CARLA 生态成熟，重点复现 teacher/student gap 与 perturbation 数据生成。

### A03 — nuPlan: A Closed-loop ML-based Planning Benchmark for Autonomous Vehicles

- **作者 / 年份 / venue**：Holger Caesar, Juraj Kabzan, Kok Seang Tan, Whye Kit Fong, Eric Wolff, Alex Lang, Luke Fletcher, Oscar Beijbom, Sammy Omari；2021；arXiv / nuPlan benchmark（后续公开 challenge）。
- **链接**：[paper](https://arxiv.org/abs/2106.11810)；[devkit](https://github.com/motional/nuplan-devkit)；[project](https://nuplan.org/nuplan)。
- **类别 / 系统角色**：benchmark；**planning evaluation/training platform**。
- **一句话定位**：以 1500 小时真实驾驶数据、non-reactive/reactive simulation 和规划专用指标建立大规模 ML planner 基准。
- **输出 / action type / 评测**：benchmark 不输出动作；支持 trajectory planners；**CL-reactive + non-reactive + OL**。
- **影响信号**：第一个大规模公开 ML planning benchmark，自称并被社区广泛使用为 closed-loop planning 基准；Diffusion Planner、Diffusion-ES、PlannerRFT 等核心落点。[^nuplan]
- **为何 A / 前后关系**：先读它才能判断 nuScenes L2、NAVSIM PDMS 与真正交互闭环的证据强弱。
- **复现建议**：**最高优先**；先跑 PDM/IDM/ML planner baseline，再研究生成式 planner。

### A04 — TransFuser: Imitation with Transformer-Based Sensor Fusion for Autonomous Driving

- **作者 / 年份 / venue**：Kashyap Chitta, Aditya Prakash, Bernhard Jaeger, Zehao Yu, Katrin Renz, Andreas Geiger；2023；IEEE TPAMI（CVPR 2021 工作的扩展版）。
- **链接**：[paper](https://arxiv.org/abs/2205.15997)；[code/project](https://github.com/autonomousvision/transfuser)。
- **类别 / 系统角色**：sensor-fusion E2E driving；**raw-sensor planner replacement**。
- **一句话定位**：用多尺度 Transformer 融合 camera perspective 与 LiDAR BEV，输出 waypoints 并由控制器执行。
- **输出 / action type / 评测**：真实 ego trajectory，`continuous trajectory`；CARLA **CL-interactive**。
- **影响信号**：公开代码、数据生成与 CARLA 基线生态影响大；NAVSIM 论文还显示其简单版本可匹配部分复杂 unified 架构。[^transfuser]
- **为何 A / 前后关系**：是从 LBC 到现代融合式 E2E 的标准入口；与 UniAD/VAD 的区别是它不追求显式全栈任务协同，而强调 sensor fusion + imitation。
- **复现建议**：**最高优先**；非常适合建立自己的 E2E training/eval 基座。

### A05 — Trajectory-guided Control Prediction for End-to-end Autonomous Driving: A Simple yet Strong Baseline (TCP)

- **作者 / 年份 / venue**：Penghao Wu, Xiaosong Jia, Li Chen, Junchi Yan, Hongyang Li, Yu Qiao；2022；NeurIPS 2022。
- **链接**：[paper](https://proceedings.neurips.cc/paper_files/paper/2022/hash/286a371d8a0a559281f682f8fbf89834-Abstract-Conference.html)；[code](https://github.com/OpenPerceptionX/TCP)；project：同代码页。
- **类别 / 系统角色**：trajectory-control coupling；**planner + control hybrid**。
- **一句话定位**：并行预测未来轨迹与多步低层控制，并让轨迹分支逐时刻指导控制分支。
- **输出 / action type / 评测**：trajectory + throttle/steer/brake，`hybrid`；CARLA **CL-interactive**。
- **影响信号**：单目强基线，直接提出“轨迹 vs control 不必二选一”的表示问题。[^tcp]
- **为何 A / 前后关系**：对规划工程师尤其重要：说明 trajectory 是可解释/可约束接口，control 是执行效率接口；后续 ThinkTwice、Driving VLA 的 action head 仍在这个张力中。
- **复现建议**：**高**；适合做 trajectory-only / control-only / fused 三套消融。

### A06 — PlanT: Explainable Planning Transformers via Object-Level Representations

- **作者 / 年份 / venue**：Katrin Renz, Kashyap Chitta, Otniel-Bogdan Mercea, A. Sophia Koepke, Zeynep Akata, Andreas Geiger；2022；CoRL 2022。
- **链接**：[paper](https://arxiv.org/abs/2210.14222)；[code](https://github.com/autonomousvision/plant)；[project](https://www.katrinrenz.de/plant)。
- **类别 / 系统角色**：object-centric planning；**planner replacement / privileged-to-sensor bridge**。
- **一句话定位**：将稠密 raster/BEV 规划改写为对象 token 序列上的 Transformer planning，并可由注意力分析重要对象。
- **输出 / action type / 评测**：ego waypoints，`continuous trajectory`；CARLA **CL-interactive**。
- **影响信号**：对象级 planning transformer 的代表公开基线；其表示思想连接 VAD 的 vector query 与 TOKEN/Driving VLA 的 object token。
- **为何 A / 前后关系**：与 TransFuser 是平行路线：一个从 raw sensor 稠密特征出发，一个从对象级抽象出发；是理解“E2E 不等于没有中间表示”的关键。
- **复现建议**：**高**；尤其适合研究目标裁剪、重要性、长尾对象与解释性。

### A07 — ST-P3: End-to-End Vision-Based Autonomous Driving via Spatial-Temporal Feature Learning

- **作者 / 年份 / venue**：Shengchao Hu, Li Chen, Penghao Wu, Hongyang Li, Junchi Yan, Dacheng Tao；2022；ECCV 2022。
- **链接**：[paper](https://www.ecva.net/papers/eccv_2022/papers_ECCV/html/1807_ECCV_2022_paper.php)；[code/project](https://github.com/OpenPerceptionX/ST-P3)。
- **类别 / 系统角色**：BEV unified perception–prediction–planning；**planner enhancement / unified stack**。
- **一句话定位**：用时空 BEV 表示统一分割、预测和规划，是 UniAD 之前“可解释 vision-only full stack”的重要节点。
- **输出 / action type / 评测**：ego trajectory，`continuous trajectory`；nuScenes **OL-log** + CARLA **CL-interactive**。
- **影响信号**：ECCV 正式发表、代码公开；其任务组合和 BEV planning setting 成为 UniAD/VAD 的直接比较对象。[^stp3]
- **为何 A / 前后关系**：先读 ST-P3 再读 UniAD，能看出后者的贡献不是“任务更多”，而是 query interface 与 planning-oriented coordination。
- **复现建议**：**中高**；适合做 BEV 时序对规划收益的消融，完整训练成本较高。

### A08 — Planning-Oriented Autonomous Driving (UniAD)

- **作者 / 年份 / venue**：Yihan Hu, Jiazhi Yang, Li Chen, Keyu Li, Chonghao Sima, Xizhou Zhu, Siqi Chai, Senyao Du, Tianwei Lin, Wenhai Wang, Lewei Lu, Xiaosong Jia, Qiang Liu, Jifeng Dai, Yu Qiao, Hongyang Li；2023；CVPR 2023 Best Paper。
- **链接**：[paper](https://openaccess.thecvf.com/content/CVPR2023/html/Hu_Planning-Oriented_Autonomous_Driving_CVPR_2023_paper.html)；[code/project](https://github.com/OpenDriveLab/UniAD)。
- **类别 / 系统角色**：unified perception–prediction–planning；**planning-oriented unified stack**。
- **一句话定位**：用 BEV 与一组贯穿 tracking、mapping、motion、occupancy、planning 的 query interface，把多任务协同明确服务于最终规划。
- **输出 / action type / 评测**：ego trajectory，`continuous trajectory`；主要为 nuScenes **OL-log**（后续工作在 CARLA/Bench2Drive 重测不等于原论文证据）。
- **影响信号**：CVPR 2023 Best Paper、公开代码、大量后续 unified E2E 以其为起点。[^uniad]
- **为何 A / 前后关系**：领域主干中的分水岭；与模块化系统不同，但也不是 raw-image-to-control 黑箱，而是“可学习接口的结构化端到端”。
- **复现建议**：**值得，但优先复现 planner/接口而非全量训练**；全栈成本与依赖很高。

### A09 — VAD: Vectorized Scene Representation for Efficient Autonomous Driving

- **作者 / 年份 / venue**：Bo Jiang, Shaoyu Chen, Qing Xu, Bencheng Liao, Jiajie Chen, Helong Zhou, Qian Zhang, Wenyu Liu, Chang Huang, Xinggang Wang；2023；ICCV 2023。
- **链接**：[paper](https://openaccess.thecvf.com/content/ICCV2023/html/Jiang_VAD_Vectorized_Scene_Representation_for_Efficient_Autonomous_Driving_ICCV_2023_paper.html)；[code/project](https://github.com/hustvl/VAD)。
- **类别 / 系统角色**：vectorized unified E2E；**efficient planner/unified stack**。
- **一句话定位**：将 agent、map 与 ego plan 全部向量化，并以 query interaction 与显式 vectorized planning constraints 提升安全和效率。
- **输出 / action type / 评测**：ego trajectory，`continuous trajectory`；原论文主要为 nuScenes **OL-log**，没有可作为主证据的 interactive closed loop。
- **影响信号**：成为 UniAD 之后最常用的高效 vectorized baseline，并直接孕育 VADv2、DiffusionDrive 等路线。
- **为何 A / 前后关系**：读完 UniAD 再读 VAD，重点比较 dense BEV task chain 与 fully vectorized representation 的取舍。
- **复现建议**：**高**；规划约束和向量 token 对泊车结构化场景也有借鉴价值。

### A10 — Bench2Drive: Towards Multi-Ability Benchmarking of Closed-Loop End-To-End Autonomous Driving

- **作者 / 年份 / venue**：Xiaosong Jia, Zhenjie Yang, Qifeng Li, Zhiyuan Zhang, Junchi Yan；2024；NeurIPS 2024 Datasets & Benchmarks。
- **链接**：[paper](https://proceedings.neurips.cc/paper_files/paper/2024/hash/017761f94a1cd66d01c041aff85492c4-Abstract-Datasets_and_Benchmarks_Track.html)；[code/data](https://github.com/Thinklab-SJTU/Bench2Drive)；project：同代码页。
- **类别 / 系统角色**：benchmark；**multi-ability closed-loop evaluation**。
- **一句话定位**：用统一训练集和 44 类交互场景、220 条短路线，分解评估 E2E 的 merge/overtake/detour/traffic-rule 等能力。
- **输出 / action type / 评测**：benchmark；支持 trajectory/control；CARLA **CL-interactive**。
- **影响信号**：NeurIPS 数据集赛道、公开训练/评测，已成为 SimLingo、ORION、LinkVLA 等 VLA 的核心闭环证据。[^b2d]
- **为何 A / 前后关系**：弥补旧 CARLA 长路线高方差和各家自采训练数据不可比；必须与 NAVSIM 并读。
- **复现建议**：**最高优先**；建议固定 simulator 版本、route seeds、runtime budget 并报告能力分项。

### A11 — NAVSIM: Data-Driven Non-Reactive Autonomous Vehicle Simulation and Benchmarking

- **作者 / 年份 / venue**：Daniel Dauner, Marcel Hallgarten, Tianyu Li, Xinshuo Weng, Zhiyu Huang, Zetong Yang, Hongyang Li, Igor Gilitschenski, Boris Ivanovic, Marco Pavone, Andreas Geiger, Kashyap Chitta；2024；NeurIPS 2024 Datasets & Benchmarks。
- **链接**：[paper](https://proceedings.neurips.cc/paper_files/paper/2024/hash/32768f7faf1995026ef9821c696f3404-Abstract-Datasets_and_Benchmarks_Track.html)；[code](https://github.com/autonomousvision/navsim)；[project](https://github.com/autonomousvision/navsim)。
- **类别 / 系统角色**：benchmark；**real-log non-reactive planning evaluation**。
- **一句话定位**：在真实日志的 BEV abstraction 中短时 unroll 候选轨迹，用 progress、collision、TTC、comfort、drivable-area 等指标替代单纯 L2。
- **输出 / action type / 评测**：benchmark；`continuous trajectory`；**NR-rollout，不是严格闭环**。
- **影响信号**：CVPR 2024 challenge 143 支队伍/463 次提交，快速成为 DiffusionDrive、GoalFlow、AutoVLA、ReCogDrive 等共同平台。[^navsim]
- **为何 A / 前后关系**：它揭示简单 TransFuser 也可匹配复杂架构，并证明 benchmark 选择会重排方法结论。
- **复现建议**：**最高优先**；适合快速迭代，但最终结论必须再用 reactive/interactive 闭环交叉验证。

### A12 — WOD-E2E: Waymo Open Dataset for End-to-End Driving in Challenging Long-tail Scenarios

- **作者 / 年份 / venue**：Runsheng Xu, Hubert Lin, Wonseok Jeon, Hao Feng, Yuliang Zou, Liting Sun, John Gorman, Ekaterina Tolstaya, Sarah Tang, Brandyn White, Ben Sapp, Mingxing Tan, Jyh-Jing Hwang, Dragomir Anguelov；2025；arXiv-only / official Waymo benchmark。
- **链接**：[paper](https://arxiv.org/abs/2510.26125)；[dataset/challenge](https://waymo.com/open/data/e2e/)；[devkit](https://github.com/waymo-research/waymo-open-dataset)。
- **类别 / 系统角色**：benchmark；**vision-based long-tail trajectory evaluation**。
- **一句话定位**：用 20 秒真实长尾片段与人类 rater preference/RFS 评估 5 秒 ego trajectory，促成 VLT pretraining + RL post-training 路线。
- **输出 / action type / 评测**：benchmark；`continuous trajectory / trajectory token`；**Rater + OL matched/ADE，不是 simulator closed loop**。
- **影响信号**：Waymo 官方 2025 challenge；Poutine、NoRD、DriveMA 等新一代 Driving VLA 的共同试验场。[^wod]
- **为何 A / 前后关系**：将评价重心从平均日志模仿移到 long-tail preference；与 NAVSIM 的规则式 PDMS、Bench2Drive 的交互闭环构成互补三角。
- **复现建议**：**高**；必须区分 validation rater labels、hidden test 与 challenge 技术报告结果。

### A13 — Behavior Transformers: Cloning k Modes with One Stone

- **作者 / 年份 / venue**：Nur Muhammad Shafiullah, Zichen Cui, Ariuntuya Altanzaya, Lerrel Pinto；2022；NeurIPS 2022。
- **链接**：[paper](https://proceedings.neurips.cc/paper_files/paper/2022/hash/90d17e882adbdda42349db6f50123817-Abstract-Conference.html)；[code](https://github.com/notmahi/bet)；[project](https://mahis.life/bet)。
- **类别 / 系统角色**：action representation；**multi-modal behavior generator**。
- **一句话定位**：用 k-means action bin 作为离散 mode token，再回归连续 residual，使 Transformer 同时保留多模态与精确动作。
- **输出 / action type / 评测**：真实 action；`discrete action token + continuous residual (hybrid)`；机器人和自驾行为数据上的 task rollout。
- **影响信号**：明确形成 BeT→VQ-BeT 路线，并把 object-detection 式“分类 + offset”引入连续行为建模。[^bet]
- **为何 A / 前后关系**：是理解 parking 中“maneuver token + continuous trajectory residual”最直接的跨域基础。
- **复现建议**：**最高优先的小型实验**；先在轨迹/gear state 上做 k-means+residual，再比较纯回归。

### A14 — Diffusion Policy: Visuomotor Policy Learning via Action Diffusion

- **作者 / 年份 / venue**：Cheng Chi, Siyuan Feng, Yilun Du, Zhenjia Xu, Eric Cousineau, Benjamin Burchfiel, Shuran Song；2023；RSS 2023。
- **链接**：[paper](https://arxiv.org/abs/2303.04137)；[code](https://github.com/real-stanford/diffusion_policy)；[project](https://diffusion-policy.cs.columbia.edu/)。
- **类别 / 系统角色**：action representation；**conditional generative policy**。
- **一句话定位**：将动作序列视为条件扩散生成问题，并以 receding-horizon execution、视觉条件和时序去噪稳定多模态行为。
- **输出 / action type / 评测**：真实连续 action chunks；`diffusion`；机器人闭环 rollout（非 driving）。
- **影响信号**：机器人策略扩散的奠基代表，DiffusionDrive 等直接以其“多步太慢”作为问题定义。[^diffpol]
- **为何 A / 前后关系**：先读它，才能判断 driving diffusion 的创新究竟在表示、采样速度、约束还是 benchmark。
- **复现建议**：**高**；不必先复现机器人全套，可在 nuPlan/parking trajectory 上复现 receding-horizon denoising。

### A15 — VADv2: End-to-End Vectorized Autonomous Driving via Probabilistic Planning

- **作者 / 年份 / venue**：Bo Jiang, Shaoyu Chen, Hao Gao, Bencheng Liao, Qian Zhang, Wenyu Liu, Xinggang Wang；2026；ICLR 2026（早期 arXiv 2024 作者表更长，以会议版为准）。
- **链接**：[paper](https://proceedings.iclr.cc/paper_files/paper/2026/hash/70925fe2336ae05917c817d5e4660ab5-Abstract-Conference.html)；[code](https://github.com/hustvl/VAD)；[project](https://hgao-cv.github.io/VADv2/)。
- **类别 / 系统角色**：trajectory tokenization / probabilistic planning；**planner replacement**。
- **一句话定位**：把高维连续规划空间先离散为大型 planning vocabulary，再 token 化并预测动作分布，而非单轨迹确定性回归。
- **输出 / action type / 评测**：真实 trajectory；`trajectory token / hybrid`；CARLA/Bench2Drive **CL-interactive** + NAVSIM **NR-rollout**。
- **影响信号**：VAD 的正式后继、ICLR 2026；把“固定轨迹 vocabulary 的收益与覆盖盲区”变成 DiffusionDrive/GoalFlow/MeanFuser 的共同对照。
- **为何 A / 前后关系**：它是 BeT/VQ 思想落到 E2E driving planning 的关键节点，也为 parking maneuver tokenization 提供直接参照。
- **复现建议**：**高**；重点复现 vocabulary size、coverage、sampling/selection 与 OOD 失败模式。

### A16 — Diffusion-Based Planning for Autonomous Driving with Flexible Guidance

- **作者 / 年份 / venue**：Yinan Zheng, Ruiming Liang, Kexin Zheng, Jinliang Zheng, Liyuan Mao, Jianxiong Li, Weihao Gu, Rui Ai, Shengbo Eben Li, Xianyuan Zhan, Jingjing Liu；2025；ICLR 2025 Oral。
- **链接**：[paper](https://proceedings.iclr.cc/paper_files/paper/2025/file/5c0cd43063f087eb32e572d040a19cd2-Paper-Conference.pdf)；[code](https://github.com/ZhengYinan-AIR/Diffusion-Planner)；[project](https://zhengyinan-air.github.io/Diffusion-Planner/)。
- **类别 / 系统角色**：diffusion planning；**structured-input planner replacement**。
- **一句话定位**：以 DiT 联合生成 ego 与邻车轨迹，并用 classifier guidance 在推理时调安全/风格，无需重型 rule-based refinement。
- **输出 / action type / 评测**：真实 joint trajectories；`diffusion`；nuPlan **CL-reactive/non-reactive** + 私有 200h 数据。
- **影响信号**：ICLR Oral、开源并形成 Flow-Planner/Hyper-Diffusion-Planner/RL fine-tuning 系列。[^diffplanner]
- **为何 A / 前后关系**：与 DiffusionDrive 平行：前者是结构化 motion planner + nuPlan，后者是 raw-sensor E2E + NAVSIM；不可只读其一。
- **复现建议**：**最高优先**；对规划工程师比纯视觉 E2E 更易拆解和落地。

### A17 — DiffusionDrive: Truncated Diffusion Model for End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Bencheng Liao, Shaoyu Chen, Haoran Yin, Bo Jiang, Cheng Wang, Sixu Yan, Xinbang Zhang, Xiangyu Li, Ying Zhang, Qian Zhang, Xinggang Wang；2025；CVPR 2025。
- **链接**：[paper](https://openaccess.thecvf.com/content/CVPR2025/html/Liao_DiffusionDrive_Truncated_Diffusion_Model_for_End-to-End_Autonomous_Driving_CVPR_2025_paper.html)；[code](https://github.com/hustvl/DiffusionDrive)；project：同代码页。
- **类别 / 系统角色**：end-to-end diffusion planning；**raw-sensor trajectory generator**。
- **一句话定位**：从多模态 trajectory anchors 附近开始截断扩散，两步去噪生成多样高质量轨迹，以 45 FPS 解决 vanilla diffusion 延迟。
- **输出 / action type / 评测**：真实 ego trajectories；`diffusion / hybrid anchors`；NAVSIM **NR-rollout**。
- **影响信号**：CVPR 2025、公开代码、成为后续 GoalFlow/GuideFlow/WAM-Flow/PlannerRFT 的强基线。[^diffdrive]
- **为何 A / 前后关系**：它把 Diffusion Policy 的通用思想变成实时 E2E driving action head；同时暴露 anchor vocabulary coverage 的结构性限制。
- **复现建议**：**最高优先**；适合直接替换 TransFuser/VAD planner head 做可控实验。

### A18 — LMDrive: Closed-Loop End-to-End Driving with Large Language Models

- **作者 / 年份 / venue**：Hao Shao, Yuxuan Hu, Letian Wang, Guanglu Song, Steven L. Waslander, Yu Liu, Hongsheng Li；2024；CVPR 2024。
- **链接**：[paper](https://openaccess.thecvf.com/content/CVPR2024/papers/Shao_LMDrive_Closed-Loop_End-to-End_Driving_with_Large_Language_Models_CVPR_2024_paper.pdf)；[code](https://github.com/opendilab/LMDrive)；project：代码页含数据/模型。
- **类别 / 系统角色**：language-conditioned E2E；**language-guided policy**。
- **一句话定位**：将多模态传感器与自然语言指令送入 LLM 驾驶框架，直接输出实时控制并发布 LangAuto 闭环 benchmark。
- **输出 / action type / 评测**：真实 control；`control`；CARLA **CL-interactive**。
- **影响信号**：CVPR 2024；较早明确完成 language instruction→closed-loop control 的公开工作。[^lmdrive]
- **为何 A / 前后关系**：它是“语言真的进入执行环”的起点；与 DriveLM 的 Graph VQA、DriveMLM 的高层行为接口必须区分。
- **复现建议**：**中高**；重点验证语言扰动、无语言基线与 latency，而不只复现总分。

### A19 — DriveVLM: The Convergence of Autonomous Driving and Large Vision-Language Models

- **作者 / 年份 / venue**：Xiaoyu Tian, Junru Gu, Bailin Li, Yicheng Liu, Yang Wang, Zhiyong Zhao, Kun Zhan, Peng Jia, Xianpeng Lang, Hang Zhao；2024；CoRL 2024。
- **链接**：[paper](https://arxiv.org/abs/2402.12289)；[project/code status](https://tsinghua-mars-lab.github.io/DriveVLM/)；code：未见完整训练代码公开。
- **类别 / 系统角色**：VLM planning；**hierarchical decision interface + trajectory proposal / dual-system enhancement**。
- **一句话定位**：scene description→scene analysis→meta-action/decision description→waypoints，并用 DriveVLM-Dual 与传统高频 planner 协同。
- **输出 / action type / 评测**：DriveVLM 输出 trajectory waypoints，DriveVLM-Dual 再细化；`meta-action + continuous trajectory (hybrid)`；nuScenes/SUP-AD **OL-log** + **Real** production-vehicle demonstration。
- **影响信号**：CoRL 2024、明确提出 hierarchical VLM planning 与 slow-fast deployment。[^drivevlm]
- **为何 A / 前后关系**：是从“解释场景”跨到“分层语义决策 + 数值轨迹”的关键桥；后续 ORION/ReCogDrive/DriveMA 都在解决其 language–action gap/latency。
- **复现建议**：**中**；完整系统不可直接复现，但 meta-action/decision/waypoint 分层非常值得迁移到泊车。

### A20 — SimLingo: Vision-Only Closed-Loop Autonomous Driving with Language-Action Alignment

- **作者 / 年份 / venue**：Katrin Renz, Long Chen, Elahe Arani, Oleg Sinavski；2025；CVPR 2025 Highlight（CARLA Challenge 2024 winning system）。
- **链接**：[paper/official](https://openaccess.thecvf.com/content/CVPR2025/html/Renz_SimLingo_Vision-Only_Closed-Loop_Autonomous_Driving_with_Language-Action_Alignment_CVPR_2025_paper.html)；[code/project](https://github.com/RenzKa/simlingo)。
- **类别 / 系统角色**：Driving VLA；**joint driving + language understanding + alignment**。
- **一句话定位**：在同一 VLM 中联合做闭环驾驶、视觉语言理解和 language–action alignment，强调 VQA 回答必须与实际行为一致。
- **输出 / action type / 评测**：真实 trajectory/control execution；`hybrid`；Bench2Drive/CARLA **CL-interactive**。
- **影响信号**：CARLA Challenge 2024 winner；将 language–action consistency 从口号变成评测任务。[^simlingo]
- **为何 A / 前后关系**：是 LMDrive 之后、LinkVLA/DriveMA 之前最关键的 alignment 节点。
- **复现建议**：**高**；尤其适合把其 alignment test 改造成“泊车语言/档位状态是否与轨迹一致”。

### A21 — AutoVLA: A Vision-Language-Action Model for End-to-End Autonomous Driving with Adaptive Reasoning and Reinforcement Fine-Tuning

- **作者 / 年份 / venue**：Zewei Zhou, Tianhui Cai, Seth Z. Zhao, Yun Zhang, Zhiyu Huang, Bolei Zhou, Jiaqi Ma；2025；NeurIPS 2025。
- **链接**：[paper](https://arxiv.org/abs/2506.13757)；[code](https://github.com/ucla-mobility/AutoVLA)；project：同代码页。
- **类别 / 系统角色**：Driving VLA；**autoregressive reasoning + trajectory generator**。
- **一句话定位**：把可行连续轨迹离散为 action tokens，与 fast/slow reasoning 在同一自回归模型中生成，再用 GRPO 优化规划质量与推理长度。
- **输出 / action type / 评测**：真实 trajectory；`discrete action/trajectory token`；nuPlan/nuScenes/Waymo **OL/NR/Rater 类** + CARLA **CL-interactive**。
- **影响信号**：NeurIPS 2025、公开代码；当前“reasoning + tokenized feasible trajectory + RL”代表。
- **为何 A / 前后关系**：将 BeT/VQ 式离散动作、Driving VLM 与 RL post-training 汇合；对泊车可直接启发 gear/maneuver/trajectory 联合 token。
- **复现建议**：**高但成本较大**；优先复现 trajectory tokenizer 与 fast/slow gating，而非全量 VLM 训练。

### A22 — ReCogDrive: A Reinforced Cognitive Framework for End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Yongkang Li, Kaixin Xiong, Xiangyu Guo, Fang Li, Sixu Yan, Gangwei Xu, Lijun Zhou, Long Chen, Haiyang Sun, Bing Wang, Kun Ma, Guang Chen, Hangjun Ye, Wenyu Liu, Xinggang Wang；2026；ICLR 2026。
- **链接**：[paper/official](https://proceedings.iclr.cc/paper_files/paper/2026/hash/ff7bf6014f7826da531aa50f4538ee19-Abstract-Conference.html)；[arXiv](https://arxiv.org/abs/2506.08052)；[code](https://github.com/xiaomi-research/recogdrive)；project：同代码页。
- **类别 / 系统角色**：Driving VLA + diffusion + RL；**VLM planner enhancement feeding continuous planner**。
- **一句话定位**：VLM 学 driving cognition，再把语言潜空间先验注入 diffusion planner，并用 DiffGRPO 直接强化安全舒适轨迹。
- **输出 / action type / 评测**：真实 continuous trajectory；`diffusion / hybrid`；NAVSIM **NR-rollout** + Bench2Drive **CL-interactive**。
- **影响信号**：ICLR 2026、完整代码/模型/QA 数据逐步开放；明确正面解决 discrete language vs continuous action mismatch。[^recog]
- **为何 A / 前后关系**：与 AutoVLA 的“统一自回归 token”是平行设计：一个把动作拉进语言空间，一个用专用连续 planner 接住语义先验。
- **复现建议**：**高**；适合研究 VLM feature 是否真的因果影响轨迹，而不只是辅助 loss。

### A23 — Poutine: Vision-Language-Trajectory Pre-Training and Reinforcement Learning Post-Training Enable Robust End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Luke Rowe, Rodrigue de Schaetzen, Roger Girgis, Christopher Pal, Liam Paull；2025；arXiv-only / 2025 Waymo WOD-E2E challenge technical work。
- **链接**：[paper](https://arxiv.org/abs/2506.11234)；[official Waymo report](https://storage.googleapis.com/waymo-uploads/files/research/2025%20Technical%20Reports/2025%20WOD%20E2E%20Driving%20Challenge%20-%20Special%20Mention%20-%20Poutine.pdf)；code/project：未确认完整公开训练仓库。
- **类别 / 系统角色**：Driving VLA；**vision-language-trajectory token model + preference RL**。
- **一句话定位**：用 CoVLA + WOD 长尾数据做 vision-language-trajectory next-token pretraining，再以不足 500 帧人类偏好做 GRPO。
- **输出 / action type / 评测**：真实 trajectory tokens；`trajectory token`；WOD-E2E **Rater + OL**，无 simulator closed loop。
- **影响信号**：2025 WOD-E2E test RFS 7.99、论文称 challenge 第 1；VLT scaling + lightweight preference RL 的强实证。[^poutine]
- **为何 A / 前后关系**：比单纯 VQA 更接近可扩展 driving foundation policy；与 AutoVLA/ReCogDrive 的差异是数据预训练和 rater-based post-training 更突出。
- **复现建议**：**中**；公开数据可做缩小版，完整 Waymo 偏好/算力和训练细节限制较大。

### A24 — EMMA: End-to-End Multimodal Model for Autonomous Driving

- **作者 / 年份 / venue**：Jyh-Jing Hwang, Runsheng Xu, Hubert Lin, Wei-Chih Hung, Jingwei Ji, Kristy Choi, Di Huang, Tong He, Paul Covington, Benjamin Sapp, Yin Zhou, James Guo, Dragomir Anguelov, Mingxing Tan；2025；Transactions on Machine Learning Research（TMLR；初版 arXiv 2024）。
- **链接**：[paper/TMLR](https://openreview.net/forum?id=kH3t5lmOU8)；[arXiv](https://arxiv.org/abs/2410.23262)；[official project](https://waymo.com/research/emma/)；code：未公开。
- **类别 / 系统角色**：VLM-based unified driving；**trajectory generator + multi-task generalist**。
- **一句话定位**：基于 Gemini，把导航/ego 状态和 trajectory、3D object、road graph 全部写进统一自然语言空间，并从相机直接生成 planner trajectory。
- **输出 / action type / 评测**：真实 planner trajectory（以文本坐标生成）；`trajectory token / natural-language serialization`；nuScenes planning **OL-log** + WOMD motion-planning proxy，无 interactive closed loop。
- **影响信号**：Waymo 官方研究；较早把 foundation MLLM、CoT、多任务感知和真实规划轨迹统一到同一生成接口。[^emma]
- **为何 A / 前后关系**：它是 DriveVLM 与 S4-Driver/AutoVLA/DriveVLA-W0 之间的重要范式节点；同时暴露“把连续几何写成文本是否高效、是否可控”的核心矛盾。
- **复现建议**：**中（概念必读、整模难复现）**；Gemini/私有训练细节不开放，但 trajectory serialization、multi-task transfer 与 latency 分析值得复刻。

### A25 — DriveMA: Driving Vision-Language-Action Models with Verifiable Meta-Actions

- **作者 / 年份 / venue**：Weicheng Zheng, Yixin Huang, Qiao Sun, Derun Li, Hang Zhao；2026；CoRL 2026。
- **链接**：[paper/latest record](https://arxiv.org/abs/2605.31271)；[code](https://github.com/Tsinghua-MARS-Lab/DriveMA)；[project](https://tsinghua-mars-lab.github.io/DriveMA/)。
- **类别 / 系统角色**：language–action alignment；**meta-action-conditioned trajectory generator**。
- **一句话定位**：把未来轨迹投影成可自动标注、可反向验证的纵向×横向 meta-action，并对“决策 turn”和“轨迹 turn”分别做 credit assignment。
- **输出 / action type / 评测**：meta-action + 真实 waypoints；`meta-action + continuous trajectory (hybrid)`；WOD-E2E **Rater/OL** + NAVSIM **NR-rollout**。
- **影响信号**：CoRL 2026、代码/2B 模型/标注公开；直接量化 trajectory–meta-action consistency，并以小模型取得强 WOD-E2E RFS。[^drivema]
- **为何 A / 前后关系**：对你的 parking 研究最关键的新论文之一：正倒车、换挡、入库阶段天然适合做可验证 meta-action；比 verbose CoT 更低熵、更低延迟。
- **版本歧义**：另有 arXiv:2605.21273《Rethinking Language Interfaces...》记录；下载阶段以项目/CoRL 引用的 **2605.31271** 为主，不重复下载。
- **复现建议**：**最高优先**；先在轨迹上实现规则投影与一致性 reward，再接 VLM。

## 3. B 级：特定方向值得深入（40 篇）

为控制篇幅，B 级采用压缩记录，但每条仍覆盖：书目信息、paper/code/project、影响信号、类别/角色、输出与 action type、评测类型、入选理由、前后关系、建议顺序和复现价值。

### B01 — Deep Imitative Models for Flexible Inference, Planning, and Control

- **作者 / 年份 / venue**：Nicholas Rhinehart, Rowan McAllister, Sergey Levine；2020；ICLR 2020。 [paper](https://openreview.net/forum?id=Skl4mRNYDr) · [code/project](https://sites.google.com/view/imitative-models)
- **定位与影响**：学习 expert trajectory distribution，再在测试时以 goal likelihood/energy 做可解释优化；是“生成模型既是行为先验又是 planner”的早期代表。
- **角色 / 输出 / action / 评测**：structured-input **trajectory generator/planner**；真实 ego trajectory；`continuous probabilistic trajectory`；动态仿真闭环。
- **为何 B / 关系 / 顺序 / 复现**：先于 Diffusion-ES、Diffusion Planner 阅读；创新重要但不是现代 raw-sensor E2E 主干。**值得复现：高**，尤其是 goal conditioning 与 OOD goal robustness。

### B02 — NEAT: Neural Attention Fields for End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Kashyap Chitta, Aditya Prakash, Andreas Geiger；2021；ICCV 2021。 [paper](https://openaccess.thecvf.com/content/ICCV2021/papers/Chitta_NEAT_Neural_Attention_Fields_for_End-to-End_Autonomous_Driving_ICCV_2021_paper.pdf) · [code](https://github.com/autonomousvision/neat)
- **定位与影响**：连续 BEV 查询函数把图像特征压缩为时空 attention field，同时预测 semantics 与 waypoints；是 TransFuser 同期的紧凑可解释表示路线。
- **角色 / 输出 / action / 评测**：raw-sensor **planner replacement**；真实 waypoints；`continuous trajectory`；CARLA **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：读 LBC 后、TransFuser 前后均可；后续对象/向量 token 路线影响更大，因此 B。**复现：中高**。

### B03 — Think Twice Before Driving: Towards Scalable Decoders for End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Xiaosong Jia, Penghao Wu, Li Chen, Jiangwei Xie, Conghui He, Junchi Yan, Hongyang Li；2023；CVPR 2023。 [paper](https://openaccess.thecvf.com/content/CVPR2023/html/Jia_Think_Twice_Before_Driving_Towards_Scalable_Decoders_for_End-to-End_Autonomous_CVPR_2023_paper.html) · [code](https://github.com/OpenDriveLab/ThinkTwice)
- **定位与影响**：coarse trajectory/action→look at critical regions→predict outcome→iterative residual refinement，强调 planner decoder 容量而非只堆 encoder。
- **角色 / 输出 / action / 评测**：**trajectory/control decoder enhancement**；`hybrid`；CARLA **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：接 TCP；是理解 proposal refinement/world imagination 的实用桥，但未定义长期主范式。**复现：高**，适合替换现有 decoder。

### B04 — DriveAdapter: Breaking the Coupling Barrier of Perception and Planning in End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Xiaosong Jia, Yulu Gao, Li Chen, Junchi Yan, Patrick Langechuan Liu, Hongyang Li；2023；ICCV 2023 Oral。 [paper](https://openaccess.thecvf.com/content/ICCV2023/html/Jia_DriveAdapter_Breaking_the_Coupling_Barrier_of_Perception_and_Planning_in_ICCV_2023_paper.html) · [code](https://github.com/OpenDriveLab/DriveAdapter)
- **定位与影响**：保留强 privileged teacher planner，让 raw-sensor student 通过 adapter/feature alignment 学会提供合适特征，并屏蔽不安全 teacher features。
- **角色 / 输出 / action / 评测**：**planner enhancement / teacher reuse**；trajectory/control `hybrid`；CARLA **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：LBC 的成熟后继；适合研究“模块化 planner 能否作为 E2E teacher”。**复现：高**。

### B05 — PPAD: Iterative Interactions of Prediction and Planning for End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Zhili Chen, Maosheng Ye, Shuangjie Xu, Tongyi Cao, Qifeng Chen；2024；ECCV 2024。 [paper](https://www.ecva.net/papers/eccv_2024/papers_ECCV/html/5165_ECCV_2024_paper.php) · [code/project](https://github.com/zlichen/PPAD)
- **定位与影响**：在每个未来时间步交替进行 prediction 与 planning，并显式建模 ego↔agent/map/BEV interaction，反对“一次预测后一次规划”。
- **角色 / 输出 / action / 评测**：**unified stack / planner enhancement**；真实 trajectory；`continuous trajectory`；nuScenes **OL-log**。
- **为何 B / 关系 / 顺序 / 复现**：UniAD/VAD 后读；对停车动态障碍逐步交互有启发，但缺少强交互闭环证据。**复现：中**。

### B06 — DriveTransformer: Unified Transformer for Scalable End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Xiaosong Jia, Junqi You, Zhiyuan Zhang, Junchi Yan；2025；ICLR 2025。 [paper](https://proceedings.iclr.cc/paper_files/paper/2025/hash/a7afc9957f1190223763b6ea93218f98-Abstract-Conference.html) · [code](https://github.com/Thinklab-SJTU/DriveTransformer)
- **定位与影响**：用 task self-attention、sensor cross-attention、temporal cross-attention 统一并行 task queries，避免顺序任务链和稠密 BEV 的扩展成本。
- **角色 / 输出 / action / 评测**：**unified sparse/streaming stack**；真实 trajectory；`continuous trajectory`；Bench2Drive **CL-interactive** + nuScenes **OL-log**。
- **为何 B / 关系 / 顺序 / 复现**：UniAD/VAD 之后读，是结构简化/scale 路线代表；影响尚不及二者。**复现：中高**。

### B07 — Hydra-MDP: End-to-End Multimodal Planning with Multi-Target Hydra-Distillation

- **作者 / 年份 / venue**：Zhenxin Li, Kailin Li, Shihao Wang, Shiyi Lan, Zhiding Yu, Yishen Ji, Zhiqi Li, Ziyue Zhu, Jan Kautz, Zuxuan Wu, Yu-Gang Jiang, Jose M. Alvarez；2024；arXiv-only / NAVSIM challenge winner。 [paper](https://arxiv.org/abs/2406.06978) · [code](https://github.com/NVlabs/Hydra-MDP)
- **定位与影响**：从 human 与 rule-based teachers 同时蒸馏，多 head 学面向不同 metric 的轨迹候选；展示 benchmark-aware teacher distillation 的工程效果。
- **角色 / 输出 / action / 评测**：**planner enhancement**；真实 multimodal trajectories；`hybrid vocabulary/continuous`；NAVSIM **NR-rollout**。
- **为何 B / 关系 / 顺序 / 复现**：NAVSIM 后读；榜单价值高，但方法结论与 PDMS/teacher 偏置绑定。**复现：高**。

### B08 — Enhancing End-to-End Autonomous Driving with Latent World Model (LAW)

- **作者 / 年份 / venue**：Yingyan Li, Lue Fan, Jiawei He, Yuqi Wang, Yuntao Chen, Zhaoxiang Zhang, Tieniu Tan；2025；ICLR 2025。 [paper](https://proceedings.iclr.cc/paper_files/paper/2025/hash/6aa4967920e495e90aeeaa3acf18d019-Abstract-Conference.html) · code：论文标注将公开，当前需下载阶段再核验 · project：未确认。
- **定位与影响**：让当前场景 feature + ego trajectory 预测 future latent feature，用自监督未来建模增强 planner 表示，而非在推理时生成像素视频。
- **角色 / 输出 / action / 评测**：**planner enhancement / latent representation learning**；trajectory；`continuous trajectory`；nuScenes **OL**、NAVSIM **NR**、CARLA **CL**。
- **为何 B / 关系 / 顺序 / 复现**：UniAD/VAD 后、DriveVLA-W0 前；world-model auxiliary 的关键过渡。**复现：中高**。

### B09 — End-to-End Driving with Online Trajectory Evaluation via BEV World Model (WoTE)

- **作者 / 年份 / venue**：Yingyan Li, Yuqi Wang, Yang Liu, Jiawei He, Lue Fan, Zhaoxiang Zhang；2025；ICCV 2025。 [paper](https://arxiv.org/abs/2504.01941) · [code](https://github.com/liyingyanUCAS/WoTE)
- **定位与影响**：对候选 ego trajectory 预测未来 BEV state 并在线评分，世界模型从“辅助表示学习”升级为 proposal evaluator。
- **角色 / 输出 / action / 评测**：**planner enhancement / trajectory selector**；真实 trajectory；`hybrid proposals + world-model scoring`；NAVSIM **NR** + Bench2Drive **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：LAW 后读；对 parking 多候选可行性评分高度相关。**复现：高**。

### B10 — GenAD: Generalized Predictive Model for Autonomous Driving

- **作者 / 年份 / venue**：Jiazhi Yang, Shenyuan Gao, Yihang Qiu, Li Chen, Tianyu Li, Bo Dai, Kashyap Chitta, Penghao Wu, Jia Zeng, Ping Luo, Jun Zhang, Andreas Geiger, Yu Qiao, Hongyang Li；2024；CVPR 2024 Highlight。 [paper](https://openaccess.thecvf.com/content/CVPR2024/html/Yang_Generalized_Predictive_Model_for_Autonomous_Driving_CVPR_2024_paper.html) · [code/data](https://github.com/OpenDriveLab/DriveAGI)
- **定位与影响**：2000h 级 driving video + language 的 latent diffusion world model，可 action-condition，并展示向 motion planner 适配。
- **角色 / 输出 / action / 评测**：主要是 **world/video model**，planning 是 downstream extension；可输出 trajectory；`diffusion / hybrid`；规划证据非其主评测。
- **为何 B / 关系 / 顺序 / 复现**：理解 DriveVLA-W0 的数据/未来预测背景；不是核心 planner，故 B。**复现：低到中**，数据/算力很重。

### B11 — ParkingWorld: End-to-End Autonomous Parking Reinforcement Learning from Corrective Experience in 3DGS Simulation

- **作者 / 年份 / venue**：Zhengcheng Yu, Changze Li, Haoran Liu, Tong Qin；2026；arXiv-only。 [paper](https://arxiv.org/abs/2605.25029) · [project/code status](https://yu-zhengcheng-11.github.io/ParkingWorld/)
- **定位与影响**：在可交互 3DGS 停车数字孪生中，将普通 rollout、人工纠正、失败轨迹与 rollback correction 分层存入 replay buffers，以 correction-in-the-loop RL 提升样本效率与 sim-to-real。
- **角色 / 输出 / action / 评测**：**parking RL policy training**；真实车辆 action/trajectory；`control / hybrid RL`；3DGS **CL-interactive + Real**（论文报告仿真与实车结果）。
- **为何 B / 关系 / 顺序 / 复现**：E2E Parking 后、RAD 前后并读；对“停车 IL 如何走向 correction/RL”非常关键，但论文新且代码开放程度有限。**复现：中，模拟器/实车资产成本高**。

### B12 — Doe-1: Closed-Loop Autonomous Driving with Large World Model

- **作者 / 年份 / venue**：Wenzhao Zheng, Zetian Xia, Yuanhui Huang, Sicheng Zuo, Jie Zhou, Jiwen Lu；2024；arXiv-only。 [paper](https://arxiv.org/abs/2412.09627) · [code](https://github.com/wzzheng/Doe)
- **定位与影响**：以多模态 next-token generation 统一文本感知、RGB future prediction 与 position-aware action tokens。
- **角色 / 输出 / action / 评测**：**unified token world model / planner**；真实 planning tokens；`trajectory token`；nuScenes planning 主要 **OL-log**，“Closed-Loop”标题不等于标准 simulator 互动闭环。
- **为何 B / 关系 / 顺序 / 复现**：VADv2 后、DriveVLA-W0 前；token-unified 概念强，评测证据需谨慎。**复现：中**。

### B13 — Think2Drive: Efficient Reinforcement Learning by Thinking with Latent World Model for Autonomous Driving

- **作者 / 年份 / venue**：Qifeng Li, Xiaosong Jia, Shaobo Wang, Junchi Yan；2024；ECCV 2024。 [paper](https://arxiv.org/abs/2402.16720) · [code/project](https://github.com/Thinklab-SJTU/Bench2Drive)
- **定位与影响**：用 privileged latent world model 作为高并行 neural simulator 训练 RL planner，并建立 CARLA-v2 corner-case evaluation。
- **角色 / 输出 / action / 评测**：**model-based RL planner**；低层 driving action；`control`；CARLA-v2 **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：LBC/Bench2Drive 后读；是 Raw2Drive 的前置，但部署仍依赖从特权状态学到的世界。**复现：中高**。

### B14 — RAD: Training an End-to-End Driving Policy via Large-Scale 3DGS-based Reinforcement Learning

- **作者 / 年份 / venue**：Hao Gao, Shaoyu Chen, Bo Jiang, Bencheng Liao, Yiang Shi, Xiaoyang Guo, Yuechuan Pu, Haoran Yin, Xiangyu Li, Xinbang Zhang, Ying Zhang, Wenyu Liu, Qian Zhang, Xinggang Wang；2025；NeurIPS 2025。 [paper](https://papers.neurips.cc/paper_files/paper/2025/hash/2ed3a566a0af6dcec424b988f1880ecc-Abstract-Conference.html) · [code](https://github.com/hustvl/RAD) · [project](https://hgao-cv.github.io/RAD/)
- **定位与影响**：把真实场景重建为可交互 3DGS digital twins，用大规模 RL 探索 OOD 状态，并以 IL 正则保持人类行为。
- **角色 / 输出 / action / 评测**：raw-sensor **RL policy training**；trajectory/action `hybrid`；3DGS **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：VADv2/Think2Drive 后；工程价值高但 benchmark 与重建资产仍新。**复现：中，基础设施成本高**。

### B15 — Raw2Drive: Reinforcement Learning with Aligned World Models for End-to-End Autonomous Driving (in CARLA v2)

- **作者 / 年份 / venue**：Zhenjie Yang, Xiaosong Jia, Qifeng Li, Xue Yang, Maoqing Yao, Junchi Yan；2025；NeurIPS 2025。 [paper](https://arxiv.org/abs/2505.16394) · [code](https://github.com/Thinklab-SJTU/Raw2Drive)
- **定位与影响**：以 privileged world model/heads 指导 raw-sensor world model 与 policy，试图把 MBRL 从特权状态推进到可部署感知输入。
- **角色 / 输出 / action / 评测**：raw-sensor **model-based RL policy**；control/trajectory `hybrid`；CARLA-v2/Bench2Drive **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：Think2Drive 的关键后继；尚未成为通用主干。**复现：中高**。

### B16 — Diffusion-ES: Gradient-Free Planning with Diffusion for Autonomous and Instruction-Guided Driving

- **作者 / 年份 / venue**：Brian Yang, Huangyuan Su, Nikolaos Gkanatsios, Tsung-Wei Ke, Ayush Jain, Jeff Schneider, Katerina Fragkiadaki；2024；CVPR 2024。 [paper](https://openaccess.thecvf.com/content/CVPR2024/papers/Yang_Diffusion-ES_Gradient-free_Planning_with_Diffusion_for_Autonomous_and_Instruction-guided_Driving_CVPR_2024_paper.pdf) · [code/project](https://diffusion-es.github.io/)
- **定位与影响**：把 diffusion trajectory prior 当作 evolutionary search 的 mutation operator，可优化黑箱非可微 cost，甚至由 LLM 生成 instruction-shaped reward。
- **角色 / 输出 / action / 评测**：**trajectory optimizer/planner**；真实 trajectory；`diffusion + search (hybrid)`；nuPlan **CL-reactive/non-reactive**。
- **为何 B / 关系 / 顺序 / 复现**：Deep Imitative Models 后、Diffusion Planner 前读；它是 planner，不是端到端 raw-sensor VLA。**复现：高**。

### B17 — GoalFlow: Goal-Driven Flow Matching for Multimodal Trajectories Generation in End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Zebin Xing, Xingyu Zhang, Yang Hu, Bo Jiang, Tong He, Qian Zhang, Xiaoxiao Long, Wei Yin；2025；CVPR 2025。 [paper](https://openaccess.thecvf.com/content/CVPR2025/html/Xing_GoalFlow_Goal-Driven_Flow_Matching_for_Multimodal_Trajectories_Generation_in_End-to-End_CVPR_2025_paper.html) · [code](https://github.com/YvanYin/GoalFlow)
- **定位与影响**：先选 goal points，再用单步 flow matching 生成并评分多模态轨迹，抑制 diffusion trajectory divergence。
- **角色 / 输出 / action / 评测**：**raw-sensor trajectory generator**；`flow + goal/anchor hybrid`；NAVSIM **NR-rollout**。
- **为何 B / 关系 / 顺序 / 复现**：DiffusionDrive 后读；其“目标点 + 生成”对 parking slot/key-point 极相关。**复现：最高优先专题**。

### B18 — GuideFlow: Constraint-Guided Flow Matching for Planning in End-to-End Autonomous Driving

- **作者 / 年份 / venue**：Lin Liu, Caiyan Jia, Guanyi Yu, Ziying Song, Junqiao Li, Feiyang Jia, Peiliang Wu, Xiaoshuai Hao, Yadan Luo；2026；CVPR 2026。 [paper](https://openaccess.thecvf.com/content/CVPR2026/html/Liu_GuideFlow_Constraint-Guided_Flow_Matching_for_Planning_in_End-to-End_Autonomous_Driving_CVPR_2026_paper.html) · [code](https://github.com/adept-thu/GuideFlow)
- **定位与影响**：将 safety/physical constraints 通过联合 EBM 直接注入 flow generation，并显式控制 driving aggressiveness。
- **角色 / 输出 / action / 评测**：**constrained trajectory generator**；`flow`；Bench2Drive **CL**、NAVSIM **NR**、nuScenes **OL**。
- **为何 B / 关系 / 顺序 / 复现**：GoalFlow 后读；新但与泊车运动学/碰撞约束高度相关。**复现：高**。

### B19 — WAM-Flow: Parallel Coarse-to-Fine Motion Planning via Discrete Flow Matching for Autonomous Driving

- **作者 / 年份 / venue**：Yifang Xu, Jiahao Cui, Zhihao Zhu, Hanlin Shang, Shan Luan, Mingwang Xu, Feipeng Cai, Neng Zhang, Yaoyi Li, Jia Cai, Siyu Zhu；2026；CVPR 2026。 [paper](https://openaccess.thecvf.com/content/CVPR2026/html/Xu_WAM-Flow_Parallel_Coarse-to-Fine_Motion_Planning_via_Discrete_Flow_Matching_for_CVPR_2026_paper.html) · code/project：下载阶段再核验。
- **定位与影响**：在离散动作空间做 flow matching，并以并行 coarse-to-fine decoder 缩短 autoregressive/diffusion action generation 延迟。
- **角色 / 输出 / action / 评测**：**trajectory generator**；`discrete trajectory token + flow (hybrid)`；NAVSIM **NR-rollout**。
- **为何 B / 关系 / 顺序 / 复现**：VADv2/GoalFlow 后；新范式、证据集中于 NAVSIM。**复现：中高**。

### B20 — PlannerRFT: Reinforcing Diffusion Planners through Closed-Loop and Sample-Efficient Fine-Tuning

- **作者 / 年份 / venue**：Hongchen Li, Tianyu Li, Jiazhi Yang, Mingyang Shang, Gaoqiang Wu, Caojun Wang, Haochen Tian, Zengrong Lin, Zhihui Hao, XianPeng Lang, Jia Hu, Hongyang Li；2026；CVPR 2026。 [paper](https://openaccess.thecvf.com/content/CVPR2026/html/Li_PlannerRFT_Reinforcing_Diffusion_Planners_through_Closed-Loop_and_Sample-Efficient_Fine-Tuning_CVPR_2026_paper.html) · code/project：下载阶段再核验。
- **定位与影响**：用双分支同时优化 trajectory distribution 与 denoising exploration，并以 nuMax 加速 nuPlan rollout 10×。
- **角色 / 输出 / action / 评测**：**diffusion planner post-training**；`diffusion`；nuPlan **CL-reactive/non-reactive**。
- **为何 B / 关系 / 顺序 / 复现**：Diffusion Planner 后读；对“IL planner 如何安全 RL 后训练”很关键，但仍新。**复现：高（若代码开放）**。

### B21 — Unleashing the Potential of Diffusion Models for End-to-End Autonomous Driving (Hyper Diffusion Planner)

- **作者 / 年份 / venue**：Yinan Zheng, Tianyi Tan, Bin Huang, Enguang Liu, Ruiming Liang, Jianlin Zhang, Jianwei Cui, Guang Chen, Kun Ma, Hangjun Ye, Long Chen, Ya-Qin Zhang, Xianyuan Zhan, Jingjing Liu；2026；arXiv-only。 [paper](https://arxiv.org/abs/2602.22801) · [code/project](https://zhengyinan-air.github.io/Hyper-Diffusion-Planner/)
- **定位与影响**：系统研究 diffusion loss、trajectory representation、data scaling 与 RL post-training，并在 6 类城市场景、200 km 实车道路测试中部署。
- **角色 / 输出 / action / 评测**：raw-sensor **E2E diffusion planner**；真实 trajectory；`diffusion`；**Real** + simulation。
- **为何 B / 关系 / 顺序 / 复现**：Diffusion Planner/PlannerRFT 后读；实车证据稀缺而宝贵，但论文新、私有数据占主导。**复现：低到中；方法消融值得复现**。

### B22 — Behavior Generation with Latent Actions (VQ-BeT)

- **作者 / 年份 / venue**：Seungjae Lee, Yibin Wang, Haritheja Etukuru, H. Jin Kim, Nur Muhammad Mahi Shafiullah, Lerrel Pinto；2024；ICML 2024。 [paper](https://arxiv.org/abs/2403.03181) · [code](https://github.com/jayLEE0301/vq_bet_official) · [project](https://sjlee.cc/vq-bet/)
- **定位与影响**：用 hierarchical residual VQ-VAE 取代 BeT 的 k-means，将高维 action chunk 变成可学习 latent tokens，并显著加快相对 diffusion 的推理。
- **角色 / 输出 / action / 评测**：**multi-modal behavior generator**；真实 action chunks；`discrete action token + residual (hybrid)`；机器人/自驾行为环境 rollout。
- **为何 B / 关系 / 顺序 / 复现**：BeT 后读；对高维 parking trajectory+gear chunk 很有用，但非 driving 专用主干。**复现：最高优先专题**。

### B23 — Learning Fine-Grained Bimanual Manipulation with Low-Cost Hardware (ACT)

- **作者 / 年份 / venue**：Tony Z. Zhao, Vikash Kumar, Sergey Levine, Chelsea Finn；2023；RSS 2023。 [paper](https://arxiv.org/abs/2304.13705) · [code](https://github.com/tonyzhaozh/act) · [project](https://tonyzhaozh.github.io/aloha/)
- **定位与影响**：以 Transformer/CVAE 一次预测未来动作 chunk，并用 temporal ensembling 执行，降低逐帧 BC 的 compounding error。
- **角色 / 输出 / action / 评测**：**action-chunk policy**；连续低层控制序列；`continuous action chunk / hybrid latent style`；机器人闭环。
- **为何 B / 关系 / 顺序 / 复现**：与 BeT/VQ-BeT 平行；可启发 parking 以 maneuver segment 而非单帧控制建模。**复现：中高**。

### B24 — Offline Reinforcement Learning as One Big Sequence Modeling Problem (Trajectory Transformer)

- **作者 / 年份 / venue**：Michael Janner, Qiyang Li, Sergey Levine；2021；NeurIPS 2021。 [paper](https://proceedings.neurips.cc/paper/2021/hash/099fe6b0b444c23836c4a5d07346082b-Abstract.html) · [code](https://github.com/jannerm/trajectory-transformer) · project：同代码页。
- **定位与影响**：把 state/action/reward 的整段轨迹离散成 token sequence，以 beam search + reward/model likelihood 做 planning。
- **角色 / 输出 / action / 评测**：**token-based offline planner**；离散 trajectory/action tokens；`trajectory token`；offline RL task rollout。
- **为何 B / 关系 / 顺序 / 复现**：在 BeT 前后并读；是 Doe-1/AutoVLA 类 next-token action generation 的算法祖先之一，但并非驾驶专用。**复现：中**。

### B25 — E2E Parking: Autonomous Parking by the End-to-End Neural Network on the CARLA Simulator

- **作者 / 年份 / venue**：Yunfan Yang, Denglong Chen, Tong Qin, Xiangru Mu, Chunjing Xu, Ming Yang；2024；IEEE IV 2024。 [paper/DOI](https://ieeexplore.ieee.org/document/10588551) · [code](https://github.com/qintonguav/e2e-parking-carla)
- **定位与影响**：surround-view images + ego state + target slot 直接输出 steer/acceleration/gear，建立 CARLA 端到端泊车闭环基线（报告约 91% success）。
- **角色 / 输出 / action / 评测**：**parking policy replacement**；真实低层控制含 gear；`control + discrete gear (hybrid)`；CARLA **CL-interactive**；主要为单次倒车入库/受限场景，非系统化 multi-shot。
- **为何 B / 关系 / 顺序 / 复现**：parking 学习线起点；后续公开数据集直接复现它。**复现：最高优先**，代码与数据生成链完整。

### B26 — ParkingE2E: Camera-Based End-to-End Parking Network, from Images to Planning

- **作者 / 年份 / venue**：Changze Li, Ziheng Ji, Zhe Chen, Tong Qin, Ming Yang；2024；IROS 2024。 [paper](https://arxiv.org/abs/2408.02061) · [code](https://github.com/qintonguav/ParkingE2E)
- **定位与影响**：target query encoder 融合多视角 RGB 与车位目标，Transformer decoder 自回归生成 waypoints，并在四个真实地下车库验证平均 87.8% success。
- **角色 / 输出 / action / 评测**：**parking trajectory generator**；真实 ego waypoints；`continuous autoregressive trajectory`；**Real** closed-loop；multi-shot/gear 的显式表示不是核心。
- **为何 B / 关系 / 顺序 / 复现**：E2E Parking 的 control 路线之后读，比较“直接控制 vs trajectory interface”。**复现：高**，ROS/实车接口有价值。

### B27 — E2E Parking Dataset: An Open Benchmark for End-to-End Autonomous Parking

- **作者 / 年份 / venue**：Kejia Gao, Liguo Zhou, Mingjun Liu, Alois Knoll；2025；arXiv-only。 [paper](https://arxiv.org/abs/2504.10812) · [code/data](https://github.com/KejiaGao/e2e-parking-carla-dataset)
- **定位与影响**：补齐 E2E Parking 原作未公开的数据，以相同控制模型复现约 85.16% target success，并公开 CARLA 生成/训练/评估链。
- **角色 / 输出 / action / 评测**：**parking benchmark/data**；基线输出 control+gear；`hybrid`；CARLA **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：紧跟 B25；影响力尚小，但它是目前最可落地的公开停车 E2E 起点。**复现：最高优先**。

### B28 — TransParking: A Dual-Decoder Transformer Framework with Soft Localization for End-to-End Automatic Parking

- **作者 / 年份 / venue**：Hangyu Du, Chee-Meng Chew；2025；arXiv-only。 [paper](https://arxiv.org/abs/2503.06071) · code/project：未确认公开。
- **定位与影响**：纯视觉 Transformer 以 dual decoder 同时处理目标软定位与轨迹，自回归输出未来坐标。
- **角色 / 输出 / action / 评测**：**parking trajectory generator**；`continuous trajectory`；目前公开证据以离线误差为主，未确认标准闭环/实车。
- **为何 B / 关系 / 顺序 / 复现**：ParkingE2E 后作为 representation 对照；结构有参考价值，证据和开放性偏弱。**复现：中**。

### B29 — SunnyParking: Multi-Shot Trajectory Generation and Motion State Awareness for Human-like Parking

- **作者 / 年份 / venue**：Jishu Miao, Han Chen, Jiankun Zhai, Qi Liu, Tsubasa Hirakawa, Takayoshi Yamashita, Hironobu Fujiyoshi；2026；arXiv-only。 [paper](https://arxiv.org/abs/2602.21682) · code/project：未确认公开。
- **定位与影响**：双分支同时预测空间轨迹与 forward/reverse 离散 motion-state sequence，并用 Fourier slot representation 提升目标交互精度。
- **角色 / 输出 / action / 评测**：**multi-shot parking trajectory generator**；`continuous trajectory + discrete motion/gear state (hybrid)`；CARLA 数据/闭环主张，需在下载审读时核对完整 protocol；无实车证据。
- **为何 B / 关系 / 顺序 / 复现**：E2E Parking/ParkingE2E 后；这是当前最贴合“换挡点/多次揉库结构化 action”的候选。**复现：最高优先专题**。

### B30 — YUKUIv2: A Key-Point Driven Diffusion Planner for Multi-Shot Autonomous Parking

- **作者 / 年份 / venue**：Jishu Miao, Han Chen, Tsubasa Hirakawa, Takayoshi Yamashita, Hironobu Fujiyoshi；2026；IEICE Transactions on Information and Systems（advance online）。 [paper/official](https://www.jstage.jst.go.jp/article/transinf/advpub/0/advpub_2026DRL0001/_article/-char/en) · code/project：未确认。
- **定位与影响**：Y-shaped planner 先预测离散运动状态转换 key-points，再以 key-point-conditioned diffusion 生成连续 multi-shot trajectory。
- **角色 / 输出 / action / 评测**：**multi-shot parking trajectory generator**；`key-point/meta-action + diffusion (hybrid)`；CARLA parking dataset，闭环 protocol/实车未见强证据。
- **为何 B / 关系 / 顺序 / 复现**：SunnyParking 后读；它恰好体现“pure regression→state transition→key-point-guided generation”。**复现：最高优先专题**。
- **歧义提示**：题名为 v2，但本轮未在 arXiv/正式索引中找到可可靠对应的“YUKUI v1”；确认下载前需查正文 reference/作者页，避免虚构前作关系。

### B31 — ParkFormer: A Transformer-Based Parking Policy with Goal Embedding and Pedestrian-Aware Control

- **作者 / 年份 / venue**：Jun Fu, Bin Tian, Haonan Chen, Shi Meng, Tingting Yao；2025；arXiv-only。 [paper](https://arxiv.org/abs/2506.16856) · [code/project](https://github.com/little-snail-f/ParkFormer)
- **定位与影响**：goal-aware BEV + pedestrian prediction，autoregressive 输出离散 throttle/brake/steer/gear control tokens，覆盖垂直与平行停车及动态行人。
- **角色 / 输出 / action / 评测**：**dynamic parking policy**；真实低层控制与 gear；`discrete control token`；CARLA **CL-interactive**，报告 96.57% success；无实车。
- **为何 B / 关系 / 顺序 / 复现**：E2E Parking 后；少数显式考虑行人互动和 gear token 的停车模型，但仓库仍标注部分资产 coming soon。**复现：中高**。

### B32 — ParkingTransformer: LLM-Enhanced End-to-End Trajectory Planning for Autonomous Parking

- **作者 / 年份 / venue**：Hauteng Wu, Xu Li, Dong Kong, Zihang Wang, Xieyuanli Chen, Benwu Wang, Wenkai Zhu；2026；arXiv-only。 [paper](https://arxiv.org/abs/2606.17082) · code/project：未确认公开。
- **定位与影响**：trajectory queries 融合 LLM implicit state、历史与 raw multi-view features，以 3D position encoding 和 coarse-to-fine decoder 输出停车轨迹。
- **角色 / 输出 / action / 评测**：**parking VLA-style trajectory generator**；`continuous trajectory + language latent (hybrid)`；CARLA **CL-interactive** + **Real**（论文报告实车平均 88.70% success）。
- **为何 B / 关系 / 顺序 / 复现**：DriveVLM/parking 子线汇合点；非常新、开放性待核验，暂不升 A。**复现：中**，先验证 LLM feature 的因果增益与 latency。

### B33 — DriveLM: Driving with Graph Visual Question Answering

- **作者 / 年份 / venue**：Chonghao Sima, Katrin Renz, Kashyap Chitta, Li Chen, Hanxue Zhang, Chengen Xie, Ping Luo, Andreas Geiger, Hongyang Li；2024；ECCV 2024 Oral。 [paper](https://arxiv.org/abs/2312.14150) · [code/data](https://github.com/OpenDriveLab/DriveLM) · [project](https://opendrivelab.com/DriveLM/)
- **定位与影响**：以 perception→prediction→planning 的 Graph VQA 构造 reasoning data/benchmark，并给出联合 E2E driving agent baseline。
- **角色 / 输出 / action / 评测**：核心是 **language reasoning benchmark**；baseline 可影响 driving action，但论文主贡献并非低层 VLA；`VQA + hybrid agent`；nuScenes/DriveLM-CARLA，闭环证据有限于 agent baseline。
- **为何 B / 关系 / 顺序 / 复现**：DriveVLM/LMDrive 前后均可；对数据构造与 structured reasoning 重要，但不能把 Graph VQA 分数当 driving capability。**复现：高（数据/评测）**。

### B34 — DriveMLM: Aligning Multi-Modal Large Language Models with Behavioral Planning States for Autonomous Driving

- **作者 / 年份 / venue**：Erfei Cui, Wenhai Wang, Zhiqi Li, Jiangwei Xie, Haoming Zou, Hanming Deng, Gen Luo, Lewei Lu, Xizhou Zhu, Jifeng Dai；2025；Visual Intelligence 3:22（初版 arXiv 2023）。 [paper/DOI](https://doi.org/10.1007/s44267-025-00095-w) · [arXiv](https://arxiv.org/abs/2312.09245) · [code](https://github.com/OpenGVLab/DriveMLM)
- **定位与影响**：把 MLLM 输出对齐到 Apollo 等模块化 planner 的 behavioral planning states，同时生成解释；LLM 不是低层 trajectory generator。
- **角色 / 输出 / action / 评测**：**high-level decision interface / planner enhancement**；meta-action；`meta-action`；CARLA Town05 Long **CL-interactive**（由模块化 stack 执行）。
- **为何 B / 关系 / 顺序 / 复现**：与 LMDrive 平行对照：前者替换高层 behavior planner，后者直接进控制环。**复现：中高**。

### B35 — ORION: A Holistic End-to-End Autonomous Driving Framework by Vision-Language Instructed Action Generation

- **作者 / 年份 / venue**：Haoyu Fu, Diankun Zhang, Zongchuang Zhao, Jianfeng Cui, Dingkang Liang, Chong Zhang, Dingyuan Zhang, Hongwei Xie, Bing Wang, Xiang Bai；2025；ICCV 2025。 [paper](https://openaccess.thecvf.com/content/ICCV2025/html/Fu_ORION_A_Holistic_End-to-End_Autonomous_Driving_Framework_by_Vision-Language_Instructed_ICCV_2025_paper.html) · [project](https://xiaomi-mlab.github.io/Orion/)
- **定位与影响**：long-history QT-Former + LLM reasoning 生成 planning instruction，再由 generative planner 输出精确轨迹，并联合优化 VQA 与 planning。
- **角色 / 输出 / action / 评测**：**Driving VLA / trajectory generator**；真实 trajectory；`language instruction + generative continuous trajectory (hybrid)`；Bench2Drive **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：DriveVLM 后、ReCogDrive 前；强闭环但后续 alignment/效率路线更具范式性。**复现：中高**。

### B36 — Drive-R1: Bridging Reasoning and Planning in VLMs for Autonomous Driving with Reinforcement Learning

- **作者 / 年份 / venue**：Yue Li, Meng Tian, Dechang Zhu, Jiangtong Zhu, Zhenyu Lin, Zhiwei Xiong, Xinhai Zhao；2025；arXiv-only。 [paper](https://arxiv.org/abs/2506.18234) · code/project：未确认完整公开。
- **定位与影响**：以长/短 CoT SFT + trajectory/meta-action reward RL，抑制仅靠 history shortcut 并使 reasoning 对 planning 更有用。
- **角色 / 输出 / action / 评测**：**Driving VLA / reasoning-planning alignment**；trajectory + meta-action；`hybrid`；nuScenes/DriveLM-nuScenes **OL-log**，无强 simulator closed loop。
- **为何 B / 关系 / 顺序 / 复现**：AutoVLA 前后；问题定义重要，证据仍偏 open-loop。**复现：中**。

### B37 — NoRD: A Data-Efficient Vision-Language-Action Model that Drives without Reasoning

- **作者 / 年份 / venue**：Ishaan Rawal, Shubh Gupta, Yihan Hu, Wei Zhan；2026；CVPR 2026。 [paper](https://arxiv.org/abs/2602.21172) · [project](https://nord-vla-ai.github.io/) · code：项目页链接，下载阶段核验完整性。
- **定位与影响**：直接以 k-disc trajectory vocabulary 预测 10 Hz action tokens，不生成 CoT；用 Dr. GRPO 缓解弱 SFT policy 的 difficulty bias。
- **角色 / 输出 / action / 评测**：**Driving VLA without explicit language reasoning**；真实 trajectory tokens；`discrete trajectory token`；NAVSIM **NR** + WOD-E2E **Rater/OL**；无 interactive closed loop。
- **为何 B / 关系 / 顺序 / 复现**：AutoVLA/Poutine 后；是“reasoning 是否必要”的重要反例，新且闭环不足所以 B。**复现：高**。

### B38 — Unifying Language-Action Understanding and Generation for Autonomous Driving (LinkVLA)

- **作者 / 年份 / venue**：Xinyang Wang, Qian Liu, Wenjie Ding, Zhao Yang, Wei Li, Chang Liu, Bailin Li, Kun Zhan, Xianpeng Lang, Wei Chen；2026；arXiv-only。 [paper](https://arxiv.org/abs/2603.01441) · code/project：下载阶段核验。
- **定位与影响**：language/action 共用离散 codebook，以 trajectory→caption 的反向 action-understanding objective 建立双向语义联系，并用两步 coarse-to-fine 解码降低 86% 延迟。
- **角色 / 输出 / action / 评测**：**Driving VLA / language-action alignment**；真实 trajectory tokens；`trajectory token + language shared codebook`；Bench2Drive **CL-interactive**。
- **为何 B / 关系 / 顺序 / 复现**：SimLingo/AutoVLA 后、DriveMA 并读；创新直接命中 gap，但尚无正式 venue 与长期复现。**复现：最高优先专题**。

### B39 — DriveVLA-W0: World Models Amplify Data Scaling Law in Autonomous Driving

- **作者 / 年份 / venue**：Yingyan Li, Shuyao Shang, Weisong Liu, Bing Zhan, Haochen Wang, Yuqi Wang, Yuntao Chen, Xiaoman Wang, Yasong An, Chufeng Tang, Lu Hou, Lue Fan, Zhaoxiang Zhang；2026；ICLR 2026。 [paper](https://proceedings.iclr.cc/paper_files/paper/2026/hash/0d70423f59c5fdd24f0dd3fa52e34623-Abstract-Conference.html) · [code](https://github.com/BraveGroup/DriveVLA-W0)
- **定位与影响**：用未来图像预测提供稠密自监督信号缓解“低维 action 监督不足”，兼容离散视觉 token 和连续视觉 feature 两类 VLA，再用轻量 action expert 保证延迟。
- **角色 / 输出 / action / 评测**：**representation pretraining / lightweight action expert**；真实 trajectory/action expert；`hybrid (world modeling + continuous action)`；NAVSIM v1/v2 **NR-rollout** + 私有大规模数据。
- **为何 B / 关系 / 顺序 / 复现**：承接 LAW/GenAD/Drive-WM，但焦点转为 world-model supervision 是否改善 action scaling；正式发表且开放，但关键 680× 数据结论不可完全复现，暂不升 A。**复现：中高**。[^w0]

### B40 — End-to-End Visual Autonomous Parking via Control-Aided Attention (CAA-Policy)

- **作者 / 年份 / venue**：Chao Chen, Shunyu Yao, Yuanwu He, Tao Feng, Ruojing Song, Yuliang Guo, Xinyu Huang, Chenxu Wu, Ren Liu, Chen Feng；2025；arXiv-only。 [paper](https://arxiv.org/abs/2509.11090) · [code](https://github.com/Joechencc/CAAPolicy)
- **定位与影响**：不用普通 loss attention，而用 control output 的反向梯度训练 Control-Aided Attention，使视觉关注落在真正引起动作变化的区域；另以短时 waypoint auxiliary 与目标车位 motion tracking 稳定策略。
- **角色 / 输出 / action / 评测**：**parking policy / perception–control coupling**；真实 control + auxiliary waypoints；`hybrid control/trajectory`；CARLA **CL-interactive**，无实车。
- **为何 B / 关系 / 顺序 / 复现**：E2E Parking 后；是解释“何种感知细节真正影响停车控制”的实用设计，但对 multi-shot/gear 的结构化建模不强。**复现：高**。

## 4. C 级与观察名单：知道 contribution，不进入本轮下载

下表不是“差论文”列表；它们之所以暂列 C，通常是因为与目标主线重复、证据仍偏 open-loop、属于预测/世界模型而非 ego planner，或主要做 reasoning/VQA 而没有可执行 action。确认时可以把其中任意工作与 B 级对调，但应维持 B≤40。

| 工作 | 年份 | 实际角色 / 输出 | 暂列 C 的理由 |
|---|---:|---|---|
| End to End Learning for Self-Driving Cars (DAVE-2) | 2016 | raw image→steering control | 历史奠基，但对今天的 trajectory/planning representation 帮助有限；读概念即可。 |
| Conditional Imitation Learning | 2018 | command-conditioned control | command conditioning 奠基；已被 LBC/TransFuser 更完整覆盖。 |
| CILRS | 2019 | image+speed→branched control | 重要工程 baseline，但不是当前候选库的 representation 主干。 |
| Roach: End-to-End Urban Driving by Imitating a Reinforcement Learning Coach | 2021 | privileged RL teacher→sensor policy | privileged teacher 路线重要，和 LBC/DriveAdapter 重叠。 |
| LAV: Learning from All Vehicles | 2022 | perception/planning joint supervision | 用场景内所有车提升监督，工程价值高但主干影响弱于 UniAD/VAD。 |
| InterFuser | 2022 | multi-sensor safety-aware control | 强 CARLA 系统基线；结构较专门，先读 TransFuser/TCP 即可。 |
| MILE | 2022 | model-based imitation / latent world model | world-model driving 代表，但后续 LAW/DriveVLA-W0 更贴 action scaling。 |
| BEV-Planner | 2022 | BEV features→trajectory | 直接 planning supervision 值得参考，与 ST-P3/VAD 的主线内容重叠。 |
| GameFormer | 2023 | interactive prediction + game-theoretic planner | structured-input planner enhancement，不是 raw-sensor E2E；可作交互建模补充。 |
| DTPP: Differentiable Joint Conditional Prediction and Cost Evaluation | 2023 | differentiable prediction/planning | 学习 cost 与条件预测重要，但不属于本库 E2E/VLA 核心。 |
| PLUTO | 2024 | nuPlan trajectory planner | 强工程 planner；若后续主攻 structured planning，可升 B。 |
| PDM-Closed / PDM-Hybrid | 2023–24 | rule-based proposal + scoring/control | 理解 nuPlan/NAVSIM 的必备 baseline，但不是独立学习范式论文。 |
| GAIA-1 | 2023 | generative driving world model | 生成视频/世界，不直接构成可执行 ego planner。 |
| DriveDreamer | 2023 | driving world model / data generation | 主要价值在生成与表征，不应因“world model”自动归入 E2E planner。 |
| Drive-WM | 2024 | multi-view world model + planning use | 可辅助 proposal evaluation，但世界预测不是 action generation 本身。 |
| Drive-OccWorld | 2024 | occupancy world model | 主要预测未来 occupancy；和真实 trajectory output 需分开评价。 |
| VISTA | 2024 | photorealistic driving world model | 适合仿真/数据生成，非直接 planner replacement。 |
| Diffuser: Diffusion Models for Offline Reinforcement Learning | 2022 | trajectory diffusion as planning | diffusion decision 基础；与自动驾驶落地隔一层，读 A14/A16 时交叉阅读即可。 |
| Flow-Planner | 2025 | interaction-aware flow planning | 与 GoalFlow/GuideFlow/WAM-Flow 重叠；作为 diffusion→flow 路线补充。 |
| DriveGPT4 | 2023 | video QA + control-signal prediction | 早期 LLM driving 原型；action 与闭环证据弱。 |
| DriveGPT4-V2 | 2025 | LLM-derived affordance→closed-loop driving enhancement | 有正式 CVPR/CARLA 闭环，但 LLM 更像特征/affordance teacher，不是统一 action vocabulary；若重视 VLM-to-policy distillation 可升 B。 |
| Drive4C | 2025 | language-guided closed-loop capability benchmark | 能补语言驾驶的能力拆解，但为 CVPR workshop benchmark，影响尚待积累。 |
| Senna | 2024 | VLM high-level command→E2E trajectory model | 真正影响 planning，但语言与低层 planner 解耦且主要 open-loop；可与 DriveVLM 对照。 |
| S4-Driver | 2025 | self-supervised MLLM motion planning | Waymo/正式 CVPR 信号强；与 EMMA 高度相邻，若更重视 scaling 可升 B。[^s4]
| OpenDriveVLA | 2025 | 2D/3D token alignment→trajectory | 输出真实轨迹，但证据主要是 nuScenes open-loop，暂列观察。[^opendrivevla]
| OpenEMMA | 2024 | open reproduction of EMMA-like planner | 开源价值高，方法创新和证据弱于 EMMA。 |
| LightEMMA | 2025 | lightweight EMMA-style model | 重点是效率跟进；适合作为 latency 对照。 |
| DriveAgent-R1 | 2026 | active perception→behavior/meta-action | 有用的高层 agent，**不直接输出可执行 trajectory/control**，因此不列核心 Driving VLA。 |
| CoVLA | 2025 | vision-language-trajectory dataset/pretraining corpus | Poutine 等的数据基础；作为 dataset 读，不单独升为 action model。 |
| TOKEN | 2024 | object-centric tokenized driving MLLM | scene token/reasoning 有参考价值；需避免把 QA/scene understanding 当 planner。 |
| VLP | 2024 | visual-language pretraining for E2E driving | 主要是 representation/planner enhancement，真实语言在线进入 action 的证据有限。 |
| ParkDiffusion | 2025 | parking-lot vehicle/pedestrian **trajectory prediction** | 名字容易误导：预测周围 agents，不是泊车 ego planner；DLP/inD，无 ego parking closed loop。[^parkdiff] |
| ParkDiffusion++ | 2026 | ego-intention-conditioned joint **prediction/what-if** | 有 endpoint intention token，但主任务仍是多 agent forecasting，不是执行停车策略。[^parkdiffpp] |
| DLP: Dynamic and Static Object Interactions in Parking Lots | 2022 | parking-lot trajectory dataset | 对动态交互有价值，但本身是 dataset/prediction 支撑。 |
| Hybrid A* Practical Search Techniques in Path Planning for Autonomous Driving | 2008/2010 | nonholonomic search planner | multi-shot/gear/可行性必须知道的传统参照，但不进入 AI 论文下载主体。 |
| Reeds–Shepp Curves | 1990 | forward/reverse shortest-path primitive | 正倒车 maneuver 的几何基础；作为教科书/经典论文交叉阅读。 |

## 5. 路线覆盖与建议的内部阅读关系

这不是最终 `reading_order.md`，只是用于检查 A/B 是否漏线：

| 路线 | 主干 A | 专题 B | 关键比较 |
|---|---|---|---|
| imitation→raw-sensor E2E | A01–A02, A04–A06 | B01–B04 | structured planner、privileged teacher、trajectory/control 双头三种范式 |
| BEV/unified/vectorized | A07–A09, A15 | B05–B09 | dense task chain vs vector queries；感知辅助规划 vs 真正联合优化 |
| evaluation | A03, A10–A12 | B17–B21 中的落地 + benchmark 复现实验 | nuPlan reactive、Bench2Drive interactive、NAVSIM NR、WOD rater 不能横向混报 |
| diffusion/flow/RL | A14, A16–A17, A21–A23 | B16–B21 | diffusion sampling、flow steps、proposal scoring、reward post-training 是平行设计轴 |
| action representation | A05, A13, A21, A25 | B22–B24, B29–B31 | continuous trajectory、control、cluster/VQ token、meta-action、gear state 的信息瓶颈不同 |
| Driving VLM→VLA | A18–A25 | B33–B39 | language 是解释、decision interface、latent prior，还是直接 action vocabulary，必须逐篇标注 |
| parking | — | B25–B32, B40 | single-shot control→waypoints→multi-shot state/key-point→diffusion/VLA-style trajectory |

## 6. 容易混淆、下载前必须再次核对的条目

1. **LMDrive ≠ DriveLM**：LMDrive 是语言指令进入 CARLA 闭环控制；DriveLM 主体是 Graph VQA 数据/benchmark，虽含 driving agent baseline，不能用 QA 分数替代闭环能力。
2. **E2E Parking ≠ ParkingE2E**：前者直接输出 steer/accel/gear 并主打 CARLA closed loop；后者自回归 waypoints 并报告真实地下车库部署。
3. **ParkDiffusion ≠ diffusion parking planner**：它预测停车场中车与人的 future trajectories；ParkDiffusion++ 做 intention-conditioned joint prediction，二者都不是直接执行 ego parking。
4. **NAVSIM ≠ reactive closed loop**：它固定其他 agent 的未来，属于 non-reactive rollout；适合快速迭代，不足以证明交互安全。[^navsim]
5. **WOD-E2E ≠ WOMD**：前者是 vision-based ego trajectory 长尾 benchmark；后者主要是 motion forecasting 数据。EMMA 同时在 nuScenes planning 与 WOMD proxy 上报告，并不等于 WOD-E2E rater 结果。
6. **VADv2 ≠ VAD 小版本更新**：VAD 是 vectorized scene + trajectory planning；VADv2 将 planning 改写为 probabilistic planning with occupancy-centric world model 和 differentiable objective。
7. **DriveAgent-R1 不是低层 VLA**：输出高层 behavior/meta-action；执行仍需下游 planner/controller。
8. **DriveMA 版本记录存在歧义**：项目/CoRL 当前引用 arXiv:2605.31271；另一个近名记录不应重复下载。
9. **YUKUIv2 的 v1 未可靠定位**：只有 v2 正式页面得到核验；不能从名字反推一个不存在或不同题目的 v1。
10. **2026 arXiv-only 工作的成绩不可与成熟基准影响力等价**：SunnyParking、ParkingTransformer、LinkVLA 等因研究问题高度契合而入 B，不代表社区验证已充分。

## 7. 我建议你重点确认的分级决策

- **A24 EMMA**：提升为 A，因为它是自然语言序列化 trajectory + 多任务 MLLM planner 的关键节点；其 open-loop、闭源和 latency 局限已明确标注。
- **A23 Poutine、A25 DriveMA**：两篇都依赖 WOD-E2E rater/非交互指标，但分别代表 VLT pretraining+preference RL 与 verifiable meta-action，和你的 research question 高度一致。
- **B29 SunnyParking、B30 YUKUIv2**：当前 parking 子线最贴近“multi-shot / gear state / key-point-conditioned generation”，但都很新，应在下载后的全文审读中重点检查 scenario splits、换挡定义和真正 closed-loop protocol。
- **B32 ParkingTransformer、B38 LinkVLA**：概念契合度高、年份新、长期复现少，故只列 B。
- **C ParkDiffusion/ParkDiffusion++、DriveAgent-R1**：不是贬低，而是严格执行“只有真正进入 ego trajectory/control 的模型才算核心 VLA/planner”。

确认后，下一阶段会对 A/B 全文按统一审读表复核（architecture figure、method、main results、ablation、limitations），有证据不成立时先调整 tier，再按正式版优先策略下载；不会因为当前草案列入就机械下载。

## Sources

以下优先列正式 proceedings、官方项目/数据页与 arXiv 原文；它们是本草案判断 venue、任务角色和评测性质的主要依据。

[^navsim]: [NAVSIM, NeurIPS 2024 official proceedings](https://proceedings.neurips.cc/paper_files/paper/2024/hash/32768f7faf1995026ef9821c696f3404-Abstract-Datasets_and_Benchmarks_Track.html)；[official code](https://github.com/autonomousvision/navsim)。论文明确将其称为 non-reactive simulation。
[^wod]: [WOD-E2E arXiv v3](https://arxiv.org/abs/2510.26125)；[Waymo official dataset page](https://waymo.com/open/data/e2e/)。RFS 是基于 rater preference 的 open-loop metric。
[^chauffeur]: [ChauffeurNet, RSS 2019 official proceedings](https://www.roboticsproceedings.org/rss15/p31.html)。
[^lbc]: [Learning by Cheating, CoRL/PMLR official paper](https://proceedings.mlr.press/v100/chen20a.html)；[official code](https://github.com/dotchen/LearningByCheating)。
[^nuplan]: [nuPlan arXiv](https://arxiv.org/abs/2106.11810)；[official devkit](https://github.com/motional/nuplan-devkit)。初版发表于 CVPR ADP3 workshop；后续数据、模拟器与 challenge 构成实际 benchmark。
[^transfuser]: [TransFuser, TPAMI arXiv version](https://arxiv.org/abs/2205.15997)；[official code](https://github.com/autonomousvision/transfuser)；[IEEE/PubMed metadata](https://pubmed.ncbi.nlm.nih.gov/35984797/)。
[^tcp]: [TCP, NeurIPS 2022 official proceedings](https://proceedings.neurips.cc/paper_files/paper/2022/hash/286a371d8a0a559281f682f8fbf89834-Abstract-Conference.html)；[official code](https://github.com/OpenPerceptionX/TCP)。
[^stp3]: [ST-P3, ECCV 2022 official paper](https://www.ecva.net/papers/eccv_2022/papers_ECCV/html/1807_ECCV_2022_paper.php)；[official code](https://github.com/OpenPerceptionX/ST-P3)。
[^uniad]: [UniAD, CVPR 2023 official open access](https://openaccess.thecvf.com/content/CVPR2023/html/Hu_Planning-Oriented_Autonomous_Driving_CVPR_2023_paper.html)；[official code](https://github.com/OpenDriveLab/UniAD)。
[^b2d]: [Bench2Drive, NeurIPS 2024 official proceedings](https://proceedings.neurips.cc/paper_files/paper/2024/hash/017761f94a1cd66d01c041aff85492c4-Abstract-Datasets_and_Benchmarks_Track.html)；[official code/data](https://github.com/Thinklab-SJTU/Bench2Drive)。
[^bet]: [Behavior Transformers, NeurIPS 2022 official proceedings](https://proceedings.neurips.cc/paper_files/paper/2022/hash/90d17e882adbdda42349db6f50123817-Abstract-Conference.html)；[official project](https://mahis.life/bet)。
[^diffpol]: [Diffusion Policy, RSS 2023 official proceedings](https://www.roboticsproceedings.org/rss19/p026.html)；[official project](https://diffusion-policy.cs.columbia.edu/)。
[^diffplanner]: [Diffusion Planner, ICLR 2025 OpenReview](https://openreview.net/forum?id=PS5kU6JfBu)；[official code](https://github.com/ZhengYinan-AIR/Diffusion-Planner)。
[^diffdrive]: [DiffusionDrive, CVPR 2025 official open access](https://openaccess.thecvf.com/content/CVPR2025/html/Liao_DiffusionDrive_Truncated_Diffusion_Model_for_End-to-End_Autonomous_Driving_CVPR_2025_paper.html)；[official code](https://github.com/hustvl/DiffusionDrive)。
[^lmdrive]: [LMDrive, CVPR 2024 official open access](https://openaccess.thecvf.com/content/CVPR2024/html/Shao_LMDrive_Closed-Loop_End-to-End_Driving_with_Large_Language_Models_CVPR_2024_paper.html)；[official code](https://github.com/opendilab/LMDrive)。
[^drivevlm]: [DriveVLM, CoRL/PMLR official paper](https://proceedings.mlr.press/v270/tian25a.html)；[official project](https://tsinghua-mars-lab.github.io/DriveVLM/)。
[^simlingo]: [SimLingo, CVPR 2025 official open access](https://openaccess.thecvf.com/content/CVPR2025/html/Renz_SimLingo_Vision-Only_Closed-Loop_Autonomous_Driving_with_Language-Action_Alignment_CVPR_2025_paper.html)；[official code](https://github.com/RenzKa/simlingo)。
[^recog]: [ReCogDrive, ICLR 2026 official proceedings](https://proceedings.iclr.cc/paper_files/paper/2026/hash/ff7bf6014f7826da531aa50f4538ee19-Abstract-Conference.html)；[official code](https://github.com/xiaomi-research/recogdrive)。
[^poutine]: [Poutine arXiv](https://arxiv.org/abs/2506.11234)；[Waymo official challenge technical report](https://storage.googleapis.com/waymo-uploads/files/research/2025%20Technical%20Reports/2025%20WOD%20E2E%20Driving%20Challenge%20-%20Special%20Mention%20-%20Poutine.pdf)。
[^emma]: [EMMA, Waymo Research](https://waymo.com/research/emma/)；[arXiv](https://arxiv.org/abs/2410.23262)。官方摘要明确列出 planner trajectories、perception objects 与 road graph outputs，同时列出短时序输入、无 LiDAR/radar 和计算昂贵等限制。
[^w0]: [DriveVLA-W0, ICLR 2026 official proceedings](https://proceedings.iclr.cc/paper_files/paper/2026/hash/0d70423f59c5fdd24f0dd3fa52e34623-Abstract-Conference.html)；[official code](https://github.com/BraveGroup/DriveVLA-W0)。
[^drivema]: [DriveMA arXiv record used by the project](https://arxiv.org/abs/2605.31271)；[official project](https://tsinghua-mars-lab.github.io/DriveMA/)；[official code](https://github.com/Tsinghua-MARS-Lab/DriveMA)。
[^s4]: [S4-Driver, Waymo Research](https://waymo.com/research/s4-driver-scalable-self-supervised-driving-multimodal-large-language-model/)。
[^opendrivevla]: [OpenDriveVLA arXiv](https://arxiv.org/abs/2503.23463)。
[^parkdiff]: [ParkDiffusion arXiv](https://arxiv.org/abs/2505.00586)。摘要将任务定义为 heterogeneous multi-agent trajectory prediction on DLP/inD。
[^parkdiffpp]: [ParkDiffusion++ arXiv](https://arxiv.org/abs/2602.20923)。摘要将任务定义为 ego-intention-conditioned joint multi-agent trajectory prediction。
