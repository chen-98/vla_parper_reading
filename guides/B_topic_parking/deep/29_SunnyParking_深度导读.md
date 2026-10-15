# SunnyParking 深度导读

> **论文**：SunnyParking: Multi-Shot Trajectory Generation and Motion State Awareness for Human-like Parking  
> **作者**：Jishu Miao, Han Chen, Jiankun Zhai, Qi Liu, Tsubasa Hirakawa, Takayoshi Yamashita, Hironobu Fujiyoshi  
> **版本与状态**：arXiv:2602.21682v1，2026-02-25；arXiv-only 版本  
> **原文**：[本地 PDF](../../../papers/B_topic/parking/B29_SunnyParking_2026.pdf) · [arXiv](https://arxiv.org/abs/2602.21682)  
> **对照版本**：[精炼导读](../29_SunnyParking_导读.md)  
> **本文定位**：面向泊车规划研究的深度导读，重点是 action representation、换挡状态、目标表示与评测边界  
> **建议用时**：先读本文 45-60 分钟，再用 60-90 分钟精读原文

## 0. 一页结论

### 论文真正提出的问题

多把泊车不是“更长、更弯的二维轨迹”。它包含离散的前进/倒车切换、短暂停顿与车位对齐；这些事件决定一段轨迹能否被车辆执行、乘客是否觉得自然。若只从图像回归 `(x,y)`，模型会在换挡位置平均化、抖动或预测错误的 maneuver 数。

SunnyParking 将每个未来 waypoint 的几何位置、航向与 **motion state** 一同预测。其最重要的主张可以写成：

$$
\text{parking plan} \ne \{(x_t,y_t)\}_{t=1}^{T}; \qquad
\text{parking plan} \approx \{(x_t,y_t,\theta_t,m_t)\}_{t=1}^{T},
$$

其中 $m_t\in\{\text{forward},\text{reverse}\}$ 是执行该点的方向原语。

这不是完整的运动学规划器：$m_t$ 不是转向、档位和速度曲线的充分描述，也没有硬碰撞或曲率约束。但它是把“多把”从隐藏在连续回归误差里的现象，提升为可以标注、预测和评价的接口。

### 核心方案

论文的三项设计形成一条完整链：

1. 四路 RGB 经 vision encoder 与 lift-splat 得到 BEV spatial feature；
2. 目标车位 `(x,y,\theta)` 不绘制为粗糙 heatmap，而以 Fourier feature 编码，通过 target-infused queries 与 BEV 做 cross-attention；
3. YUKUI dual branch 先解码 trajectory feature/waypoints，再让 motion-state decoder 读取该隐藏特征并预测逐点前进/倒车序列。

损失由 waypoint MSE 与 motion cross-entropy 组成；额外的 GT-aware smoothness 仅在远离真值换挡点的稳定区间施加，使模型不在平稳段无意义切换，又不压制真正的换挡。

### 它在自动泊车栈中的位置

```text
surround-view camera + selected slot pose
                  ↓
learned perception / BEV representation
                  ↓
SunnyParking: trajectory + forward/reverse-state proposal
                  ↓
missing in this paper: kinematic feasibility projection, collision checker,
                       controller integration, interactive closed-loop recovery
                  ↓
vehicle actuation
```

因此最准确的分类是：**目标条件的、视觉到轨迹与运动原语的开环 imitation planner**。它不能被描述为“端到端闭环泊车系统”，也不应与报告成功率的 control policy 直接横比。

## 1. 为什么泊车会暴露纯几何轨迹的缺陷

普通道路驾驶通常以前进为主，短时局部 trajectory 可近似连续地由 PID/MPC 追踪。狭窄车位中的停车则存在离散拓扑：

```text
approach → forward alignment → stop → reverse into slot
             ↑                                ↓
             └──── forward correction ← stop ┘
```

一个错误的换挡点不是小的局部 L2 误差。它会改变后续运动方向，导致车身扫掠区域、可达姿态与碰撞风险全部变化。两个后果尤其重要：

- **多模态平均化**：同一初始姿态可能有一把入位或两三把修正两类专家风格；最小二乘回归可能得到一种两者都不真正可执行的折中曲线。
- **错误传播**：如果第一个 `forward → reverse` 边界偏移，后续点即使逐点接近 GT，也可能处于错误方向状态。

传统 Hybrid A*、Reeds-Shepp 与优化方法以状态、控制和运动学显式处理这些离散切换，但往往需要地图、标定、碰撞检查与代价函数工程。SunnyParking 的目标不是替换这些保证，而是探索：能否从人类演示中直接学习“何时应前进/倒车”的可检查中间变量。

## 2. 数据、任务与标签：先把评测对象说清楚

### 2.1 单个训练样本

每条人工驾驶轨迹 $i$ 在时刻 $j$ 包含四路图像、目标车位、未来轨迹和未来状态。经过切片，一个训练样本可概括为：

$$
(I_j^{1:R}, S) \longmapsto (T'_{j}, M'_{j}),
$$

其中 $S=(x_s,y_s,\theta_s)$，未来窗口长度为 $Q=30$。数据采样为 5 Hz，故每个预测窗口约为 6 s。论文将 trajectory 表示为含位置和朝向的点序列，模型/图表则重点展示 spatial waypoint 与方向状态。

纵向速度阈值产生三类原始标签：

$$
M(v)=
\begin{cases}
\text{forward},&v>0.05\;\text{m/s}\\
\text{reverse},&v<-0.05\;\text{m/s}\\
\text{stationary},&|v|\le 0.05\;\text{m/s}.
\end{cases}
$$

一个容易漏掉的细节是：stationary 会保留为有意义的 maneuver pause，但 motion decoder 的序列化只预测 forward/reverse。作者称这是为了避免第三类导致的标签不平衡、并让部署时以近零速度处理停顿。也就是说，文中“motion state awareness”最终是二元 **direction awareness**，而不是完整三态 gear/velocity policy。

### 2.2 数据分布决定了它能证明什么

数据在 CARLA 0.9.13 的 Town04_Opt 采集。16 个目标车位周围放置静态车辆；起点在车位入口前的离散网格上采样，并叠加位置/航向 jitter。8 位驾驶员用 Logitech G29 方向盘、油门、刹车与变速箱完成入位。成功采集标准为最终位置误差小于 0.25 m、航向误差小于 2.5°。

原始数据过滤后保留 562 条任务：25 个 1-shot、111 个 2-shot、120 个 3-shot、306 个 4-shot。4-shot 比例达到 54%，研究目标很明确：让训练与报告集中于多次换挡，而不是让 1-shot 简单任务主导平均指标。

但这也造成分布偏置。论文的定性结果显示，模型有时将原本 1-shot 的 GT 预测为 3-shot；作者归因于训练集中 3/4-shot 占多数。它提醒我们：**学习到的“人类式换挡次数”是数据分布属性，不是由几何可行性自动推导的最优解。**

## 3. 架构总览：连续目标条件化的双分支 planner

### 3.1 按 Figure 2 走完一次前向传播

Figure 2 容易让人误以为模型只是“一个 BEV encoder 后面加两个 decoder”。实际上它有两条输入流、两次含义不同的 attention 融合，以及一条从 trajectory branch 单向流向 motion branch 的依赖。最简洁的阅读方式是从左到右看：

```text
Input A: 4 × RGB images                         Input B: selected slot pose
            │                                         S = (x_s, y_s, theta_s)
            ▼                                                   │
      image backbone                                             ▼
            │                                  position Fourier + yaw sin/cos
            ▼                                                   │
       lift-splat                                                ▼
            │                                                  MLP
            ▼                                                   │
  F_spatial: BEV scene feature                 learned spatial queries + goal vector
            │                                                   │
            └────────────── K, V ── cross-attention ── Q ─────┘
                                           │
                                           ▼
                           F_target-aware: target-aware BEV feature
                                           │
                         ┌─────────────────┴─────────────────┐
                         ▼                                   │
             trajectory Transformer branch                   │
                         │                                   │
             hidden trajectory features H_T                  │
                         │                                   │
                         └── cross-attend into motion queries┘
                                                             ▼
                                              motion-state Transformer branch
                         │                                   │
                         ▼                                   ▼
       trajectory sequence {(x_t,y_t,theta_t)}    state sequence {forward_t, reverse_t}
                         \___________________________  ___________________________/
                                                     one-to-one at every t
```

下面按模块解释。这里的符号是为理解数据流而写的紧凑记法，不表示论文公开了全部 tensor shape、head 数或层数；这些实现细节在正文中没有完整给出。

#### Step A - 从环视图像获得“环境在哪里”

四路环视 RGB 先经 image backbone 提取视角特征，再由 lift-splat 投影到俯视空间，得到 BEV spatial feature $F_{spatial}$。这一支回答的是：障碍物、车位线、地面边界和自车周边的视觉几何在哪里。

它仍是 **BEV 环境表示**，不是把整个模型改成不使用 grid。论文训练设定里 BEV 覆盖 20 m × 20 m、大小为 `200 × 200`；SunnyParking 的连续性只针对车位目标如何进入网络，而非取消环境 BEV。

#### Step B - 从连续车位 pose 构造“该去哪里”

目标车位不是画入 BEV 的 mask，而是以 $S=(x_s,y_s,\theta_s)$ 单独走一条条件分支：

$$
S \rightarrow [x_s,y_s,\gamma(x_s),\gamma(y_s),\sin\theta_s,\cos\theta_s]
\rightarrow \mathrm{MLP} \rightarrow t_{global}.
$$

其中 $\gamma$ 是多频 Fourier mapping。接着，$t_{global}$ 加到每个可学习 spatial query $s_j$ 上，形成目标条件 query：

$$
q_j=s_j+t_{global}.
$$

Figure 2 中的 `Query Infusion` 就是这一步；随后还经过 self-attention。直觉上，每个空间 query 都同时带有“我原来代表 BEV 的哪个位置”和“现在要去哪个连续车位”的信息。

#### Step C - 第一次 attention：让目标决定从环境中读什么

在 Cross-domain Target Fusion 中，目标条件化 queries 为 $Q$，BEV spatial feature 为 Key/Value：

$$
F_{target-aware}=\mathrm{CrossAttn}(Q_{goal},K=F_{spatial},V=F_{spatial}).
$$

这一层不是在预测轨迹；它只产生“对于这个 slot 已经重加权过”的场景特征。若把目标从左车位移动到右车位，环境图 $F_{spatial}$ 可以相同，但 $Q_{goal}$ 改变，因此网络会从不同的空间区域取证。这就是连续 slot pose 实际进入 planner 的位置。

#### Step D - trajectory branch：先回答“车身中心线怎样走”

YUKUI 的 trajectory branch 用自己的 learnable trajectory queries 查询 $F_{target-aware}$，产生未来 waypoint 的表示 $H_T$，再解码成 trajectory sequence。论文将位置/朝向做序列化，以 token 形式组织生成；在物理空间中，对应的是未来点的 $(x_t,y_t,\theta_t)$。

因此这个分支的职责是几何：它不先预测 gear，也不直接输出 steering/throttle。若只保留这一个分支，模型本质上接近“以更好目标融合实现的 ParkingE2E 类 trajectory generator”。

#### Step E - 第二次 attention：让状态分支读懂“这条轨迹意味着前进还是倒车”

motion branch 并不是平行地从 BEV 直接分类。它先让 motion queries 对 trajectory hidden feature $H_T$ 做 cross-attention，再用更轻的 Transformer decoder 从 $F_{target-aware}$ 读取空间上下文：

$$
Q_{motion}'=\mathrm{CrossAttn}(Q_{motion},K=H_T,V=H_T),
$$

$$
H_M=\mathrm{MotionDecoder}(Q_{motion}',K=F_{target-aware},V=F_{target-aware}).
$$

最后 $H_M$ 输出逐点 forward/reverse logits。这个顺序很关键：motion state 不是只看当前图像问“应该倒车吗”，而是看 **trajectory branch 已打算画出的那条轨迹**，再给每一段赋方向。论文的设计意图是降低“几何轨迹像倒车弧线、状态却预测前进”这一类不一致。

#### Step F - 两个输出如何对齐，以及它们没有如何闭环

两条输出在时间维度上逐点对齐：

| 预测时刻 | trajectory branch | motion branch | 可解释的 maneuver 含义 |
|---:|---|---|---|
| $t=1$ | $(x_1,y_1,\theta_1)$ | forward / reverse | 起始小段应如何运动 |
| $t=2$ | $(x_2,y_2,\theta_2)$ | forward / reverse | 延续或接近切换 |
| $\ldots$ | $\ldots$ | $\ldots$ | $\ldots$ |
| $t=30$ | $(x_{30},y_{30},\theta_{30})$ | forward / reverse | 该窗口末段的方向 |

训练时，trajectory 以 MSE 与专家点序列对齐；motion 以 cross-entropy 和 shift-aware smoothness 对齐。部署接口在原文中仍是预测序列本身：论文并没有给出一个“将 motion logits 转成 gear、先停车、再执行下一段”的闭环控制器，也没有用 vehicle model 强制 $m_t$ 与速度符号、零速和曲率一致。因此要将 Figure 2 正确理解成 **trajectory proposal + maneuver annotation**，而非已经闭合的 hybrid controller。

### 3.2 三种 query 不要混为一谈

Figure 2 里 query 出现三次，功能不同，是理解架构最容易卡住的地方：

| Query | 在哪里 | 数量/语义 | 它解决的问题 |
|---|---|---|---|
| spatial queries | Fourier goal fusion | 与 BEV 网格位置对应的一组可学习 query | 连续 slot pose 应让模型关注哪一片环境 |
| trajectory queries | trajectory branch | 面向未来 trajectory sequence 的 learnable query | 每个未来时刻的几何 waypoint 应是什么 |
| motion queries | motion branch | 面向未来 state sequence 的 query，先吸收 $H_T$ | 同一时刻的 waypoint 是前进还是倒车执行 |

也因此，SunnyParking 不是“目标向量直接喂给 Transformer，然后预测两个头”。它是先把目标转为 **空间注意力条件**，再将生成的几何计划变成 **状态分支的条件**。

### 3.3 为什么 rasterized goal 不够

若把目标车位中心和方向绘制在 0.1 m/pixel 的 BEV heatmap 中，位置在栅格边界附近发生小幅移动时，输入可能完全不变或突然跳一个 pixel。对一般车道级规划，这种近似未必致命；对窄车位终姿与换挡边界，10 cm 离散化会污染目标条件。

SunnyParking 将归一化位置映射到多频 Fourier features：

$$
\gamma_{pos}(p')=[\sin(2^0p'),\cos(2^0p'),\ldots,
\sin(2^{L-1}p'),\cos(2^{L-1}p')],\quad L=12,
$$

并将 $x'$、$y'$ 与其 Fourier features 连接；yaw 以 $[\sin\theta,\cos\theta]$ 表示，避免角度 $-\pi/\pi$ 不连续。论文声称该频率设置的理论分辨率约 1.2 cm，并给出 1-2 mm 的有效精度说法。这个数值反映的是 **编码表达能力**，而不是端到端实际停车误差。

### 3.4 Cross-domain target fusion

不要把它理解为“向视觉特征加一个 goal vector”。数据流是：

1. 四相机图像经 image encoder、lift-splat 到 $F_{BEV}\in\mathbb{R}^{H\times W\times C}$；
2. Fourier target encoding 经 MLP 投影成 $t_{global}\in\mathbb{R}^{C}$；
3. 每个空间位置有一个可学习 query $s_j$，构成 $q_j=s_j+t_{global}$；
4. 目标注入后的 $q_j$ 作为 Query，带位置编码的 BEV tokens 作为 Key/Value，经 Transformer decoder 输出 $F_{enhanced}$。

$$
q_j=s_j+t_{global},\qquad
F_{enhanced}=\mathrm{CrossAttn}(Q, K(F_{BEV}), V(F_{BEV})).
$$

这使目标 slot 从一开始便影响“应从哪些图像/BEV 位置读取信息”。论文 Figure 6 的 attention 可视化显示：在倒车阶段，完整模型更关注车辆尾部和目标车位；BEV-goal 基线则出现周期性、与输入脱钩的图案。可视化是合理的诊断线索，但不是因果证明；最有说服力的证据仍是 goal perturbation 与闭环 counterfactual test，原文尚未提供。

## 4. YUKUI dual branch：轨迹与运动状态如何耦合

### 4.1 序列化与 trajectory branch

论文把连续 position/heading 限定在预测范围 $R_k$ 后量化为 token：

$$
\mathrm{Ser}(P^k)=\left\lfloor \frac{|P^k+R_k|}{2R_k}N_u\right\rfloor,
\quad k\in\{x,y,\theta\}.
$$

其中 trajectory vocabulary 上限 $N_u=1200$；motion vocabulary 上限 $N_v=100$。这并不意味着最终系统只输出离散轨迹；论文使用 token 序列组织 autoregressive decoding，同时以连续 waypoint MSE 训练和报告几何误差。需要在复现时明确：量化/反量化规则、teacher forcing 比例与连续损失是潜在的性能敏感点。

trajectory branch 的 Transformer decoder 以 learnable queries 查询 $F_{enhanced}$，得到 waypoint 序列及其隐藏表示。作者给该整体称为 **YUKUI**，即 Y-shaped Unified Kinematic and Uncertainty-aware Imitation planner；从文中可验证的实现看，它最明确的“kinematic”量是 forward/reverse motion state，而非一个显式车辆运动学模型。

### 4.2 motion branch 不是并联多任务头

motion branch 的 query 先 cross-attend trajectory branch 的 hidden feature，再进入一个较轻的 Transformer decoder，并再次查询 $F_{enhanced}$。因此依赖关系是：

```text
target-aware BEV ──→ trajectory decoder ──→ trajectory hidden states
       │                                             │
       └─────────────────→ motion decoder query fusion ┘
                                                     ↓
                                      forward/reverse state at every point
```

这种方向是有意的：状态要解释正在生成的几何轨迹。它可能减少“轨迹已转入倒车弧线，但状态头仍预测前进”的不一致。但论文没有反向用 motion state 去约束/修正 trajectory decoder，也没有将 $m_t$ 送入车辆模型；所以它是 feature-level coupling，而非严格的 hybrid-system planning。

## 5. 损失：如何既允许换挡又避免抖动

总损失为：

$$
L_{total}=\lambda_{wp}L_{waypoints}+\lambda_{motion}L_{motion},
$$

其中 waypoint loss 为 MSE。状态损失写为：

$$
L_{motion}=L_{CE}+\lambda_{smooth}L_{smooth}.
$$

$L_{smooth}$ 是 masked L1：在真值换挡点附近的时间窗口，mask 关闭，不处罚状态快速变化；其余稳定段处罚不连续/抖动预测。思路可以抽象为：

$$
L_{smooth}\propto\sum_t \mathbf{1}[t\notin\mathcal{N}(\mathcal{T}_{shift})]
\lVert \hat m_t-\hat m_{t-1}\rVert_1.
$$

它解决的是状态序列的 time-consistency，而不是车辆轨迹的运动学可行性。未来在此基础上至少应加入：

- 同档位速度符号的一致性；
- 换挡前后的零速/最小停顿约束；
- 由轴距与最大转角决定的曲率、曲率变化率约束；
- 车身 footprint 与静态/动态占据的碰撞约束；
- 每个 maneuver 的终止条件与下一段可达性。

## 6. 实验：结果支持什么、不支持什么

### 6.1 训练与基线公平性

训练使用两张 RTX A6000、30 epochs、batch size 24、Adam、初始学习率 $2\times10^{-4}$，并以 0.5 做 gradient clipping。BEV FOV 为 $[-10,10]$ m，尺寸 $200\times200$，即 0.1 m/pixel。训练时将目标位置扰动 ±0.3 m、yaw 扰动 ±2°。

对照包含 ParkingE2E 和为同一视觉输入改造的 TransFuser；后者以目标车位二维坐标为 goal。这个设定有价值，因为它排除了传感器数目的差异，但仍要避免将结果解释为“原始 TransFuser 的正式成绩”。

Scheduled Sampling 从 epoch 5 到 25，将下一步输入为 GT token 的概率线性从 1 降到 0，之后全自回归。完整模型反而受损，值得在复现中作为一项需重测而非默认继承的结论。

### 6.2 指标矩阵

轨迹指标包括逐点 L2、Fourier descriptor distance、Hausdorff distance 和平均航向误差（AHE）；状态指标包括逐时刻 motion accuracy 和按 1/2/3/4-shot 分组的换挡点二维位置误差。

| 方法 | L2 ↓ | Fourier diff. ↓ | Hausdorff ↓ | AHE ↓ | 换挡点误差均值 ↓ |
|---|---:|---:|---:|---:|---:|
| 改造的 TransFuser | 1.077 | 19.949 | **1.154** | 未报 | 1.528 |
| ParkingE2E | 3.505 | 40.032 | 3.760 | 未报 | 5.685 |
| SunnyParking | **1.065** | **19.282** | 1.169 | 5.5° | **1.152** |

正确结论是：SunnyParking 在 L2、shape descriptor 与换挡位置误差上更好，但 Hausdorff 略不如 TransFuser。它并非无条件“轨迹质量全面 SOTA”。而且这些都是与单条人工示范的开环匹配，尚不能回答是否碰撞、能否顺利入位、是否用了多余的换挡。

### 6.3 消融告诉我们的因果链

以下数值最能支撑方法论：

| 配置 | L2 ↓ | AHE ↓ | motion accuracy ↑ | 换挡点平均距离 ↓ |
|---|---:|---:|---:|---:|
| BEV + trajectory only | 3.505 | - | - | - |
| Fourier + trajectory only | 2.863 | - | - | - |
| BEV + ext. trajectory + motion | 1.474 | 9.8° | 0.827 | 1.900 |
| Fourier + ext. trajectory + motion（完整模型） | **1.065** | **5.5°** | **0.838** | **1.152** |
| 完整模型 + Scheduled Sampling | 1.421 | 7.3° | 0.758 | 1.531 |

可接受的解释是：连续 Fourier goal 和显式 direction state 在该数据上互补，且 trajectory-state coupling 关联到更小的几何误差。不可接受的外推是：“motion classification 因而保证物理可行”“模型已经学会最少换挡”或“attention 可视化证明了对车位的因果理解”。

### 6.4 缺失的闭环证据

作者在 conclusion 前明确表示，closed-loop testing 仍是验证最终 success rate 所需的下一步。原文没有报告：

- CARLA 交互式执行时的 parking success、碰撞、卡死与平均换挡数；
- 控制器如何跟踪输出轨迹，如何将 motion state 变成 gear/速度指令；
- 初始 pose 扰动、目标 slot 扰动和感知噪声下的 recovery；
- 动态车辆/行人会对 ego maneuver 产生何种响应；
- 多随机种子、训练/测试场景泄漏控制与置信区间。

因此它是非常有启发的 representation paper，而不是已完成部署证明的 parking policy。

### 6.5 与 ParkingE2E、OpenDriveVLA 的组会对照：不要把三种“连续性”混在一起

如果组内已经分享过 ParkingE2E 与 OpenDriveVLA，SunnyParking 最值得讨论的并不是“它也用了 Transformer/VLM 风格的 query”，而是它在 **目标表示** 和 **动作表示** 两个接口上同时改变了问题。先分清三个容易混淆的概念：

1. **连续目标条件（goal representation）**：车位终点以连续 pose 还是 BEV 栅格/heatmap 给模型；
2. **连续轨迹语义（trajectory in physical space）**：部署给控制器的是不是米制 waypoint；
3. **离散生成形式（decoder representation）**：网络内部是直接回归坐标，还是将坐标量化为 token 后自回归生成。

三者不是一回事。SunnyParking 的第一个接口是连续的，第二个接口也是米制 trajectory，但第三个接口仍带有 tokenization；因此不能笼统说它是“纯连续生成”。

#### 6.5.1 方法矩阵

| 维度 | ParkingE2E | SunnyParking | OpenDriveVLA |
|---|---|---|---|
| 任务 | 指定车位的实车泊车 | 指定车位的 multi-shot 泊车 | 城市道路的语言条件轨迹规划，不是车位入位 |
| 目标/意图输入 | 将指定车位**栅格化为 BEV target heatmap**，CNN 得到 target feature | 直接编码连续 slot pose `(x,y,yaw)`；位置用 Fourier features，yaw 用 `sin/cos` | 没有停车终点 pose；输入为 ego state + 高层驾驶 command 文本 + scene/agent/map visual tokens |
| 环境表示 | 环视 RGB lift-splat 到 BEV，`200 × 200`，20 m × 20 m，即 0.1 m/pixel | 环视 RGB 到 BEV；论文训练设定同为 20 m × 20 m、`200 × 200` | 2D/3D instance-aware token；内部 BEV feature map 为 `200 × 200` |
| 轨迹输出的物理含义 | 自回归未来 `(x,y)` waypoint，交给 RWF + PID 跟踪 | 未来 trajectory（含位置/朝向）+ 每点 forward/reverse state | 3 s 内 6 个 `(x,y)` ego waypoint，条件于 command |
| 解码形式 | `(x,y)` 坐标量化为 token，自回归 Transformer 解码，`N_t=1200` | 位置/朝向量化 token 序列；trajectory branch 后接 motion-state branch，`N_u=1200` | 6 个 waypoint 量化为 LLM 的文本/离散 trajectory tokens，自回归生成 |
| 关键 action abstraction | 单一 waypoint 序列 | `trajectory + direction state` 的 hybrid action | 语言条件的短时 waypoint；未显式建模 gear/maneuver state |
| 主要证据 | 四个真实车库闭环，论文报告平均 87.8% success | CARLA 静态停车场的开环轨迹/换挡点预测；无完整闭环成功率 | nuScenes 开环规划 + QA；没有停车闭环证据 |

这张表的第一条结论是：**SunnyParking 和 ParkingE2E 的根本差异不是“一个是连续轨迹、一个不是”。** ParkingE2E 最终也会解出米制 waypoint 给控制器；SunnyParking 的 decoder 也会将坐标序列化。更准确的说法是：

```text
ParkingE2E：goal 先栅格化；action 只有 trajectory
SunnyParking：goal 保持连续 pose；action = trajectory + forward/reverse state
OpenDriveVLA：没有精确 slot goal；以语言 command 条件化短时 trajectory
```

#### 6.5.2 SunnyParking 的连续 goal 到底改变了什么

ParkingE2E 的 target encoder 明确先在 BEV 中生成 target heatmap，再以 CNN 得到 $F_{target}$，并用该 feature 查询 camera BEV feature。它的优点是：目标与障碍、车位线、可行驶空间处在同一张空间图上，attention 的位置对应关系很直观；该系统还在真实车辆中成功接上控制器。

代价是，输入车位 pose 必须经过 BEV 栅格化。对于其 $[-10,10]$ m、`200 × 200` 设置，基础 grid 间距为 0.1 m。即使 heatmap/CNN 可以学习亚栅格的补偿，目标在 cell 边界附近的微小变化也不再以原始连续值、原始 yaw 直接传给 decoder。这是 **goal quantization** 问题，不等于网络所有 feature 都只能有 0.1 m 精度。

SunnyParking 保留了环境 BEV，因此它没有放弃 BEV 的局部几何与可解释性；不同之处只在 goal path：

$$
S=(x_s,y_s,\theta_s)
\xrightarrow{\text{Fourier + }[\sin\theta_s,\cos\theta_s]}
t_{global}
\xrightarrow{\text{target-infused spatial queries}}
F_{enhanced}.
$$

这样，slot 的位置和朝向以连续变量改变 query，而不是先被画成一块固定大小的 BEV 图案。对窄车位、车位边缘、初始姿态微扰和最终 heading tolerance，这个归纳偏置是合理的。论文中 Fourier+motion 的完整模型比 Fourier trajectory-only 模型的 L2 从 2.863 m 降到 1.065 m，也优于对应 BEV+motion 的 1.474 m；但这两个变化同时涉及 state branch，不能把全部收益简单归于 Fourier encoding。严格验证应保持 decoder 和 state branch 不变，只替换 heatmap goal 与 Fourier goal。

#### 6.5.3 OpenDriveVLA 为什么不是“连续目标 vs BEV 目标”的直接对照

OpenDriveVLA 是很好的 VLA 方法论参照，却不是 SunnyParking 的 target-representation baseline。它处理的是城市道路：高层 command 如“直行/右转”提供的是**语义意图**，并非“在 `(x,y,\theta)` 车位终止”的度量目标。模型用 2D/3D scene、agent、map token，ego state 和 command 驱动 LLM，生成 3 秒、每 0.5 秒采样的 6 个 `(x,y)` waypoint token。它的 `200 × 200` BEV 主要服务于环境/agent/map token 提取，而不是将一个停车终点画成 goal heatmap。

所以组会里不宜说“OpenDriveVLA 也用连续目标”。更严谨的表述是：

- **OpenDriveVLA 的强项**：用多阶段 vision-language alignment、agent-environment-ego 辅助建模，把高层语言意图接到空间化的短时轨迹；
- **它没有解决的泊车接口**：厘米级 slot pose grounding、forward/reverse/stop/gear transition、长时 multi-shot completion，以及停车闭环恢复；
- **SunnyParking 的强项**：为最后几十厘米的精确终止状态提供连续 goal grounding，并把最重要的离散 maneuver 边界显式化；
- **它没有获得的 OpenDriveVLA 能力**：语言指令跟随、通用场景语义、对象级交互推理和规模化 VLM 先验。

一个额外的工程信号是：OpenDriveVLA 论文在单张 A100 上报告的 0.5B 模型平均推理延迟约 1.36 s。即使这不是端到端控制周期的唯一测量，它也说明不能不加分层/快速轨迹头，就将这种自回归 VLA 直接放进高频、狭窄的泊车控制环。

#### 6.5.4 一条可用于分享的主线

可以把三篇论文讲成同一问题的三个层级：

```text
ParkingE2E：如何从图像和“一个目标车位”生成可被控制器跟踪的轨迹？
    → 给出 heatmap goal + trajectory-only 的实车闭环基线

SunnyParking：若车位很窄且需要多次前倒切换，目标与动作接口是否还够？
    → 改成 continuous slot pose + trajectory/direction hybrid action

OpenDriveVLA：如何让高层语言和 3D 场景语义影响轨迹？
    → 用 VLA 对齐与交互 token，但尚未提供泊车的精确终止与 maneuver 接口
```

由此可以提出一个比“给停车模型加 LLM”更尖锐的研究问题：**语言应描述哪一层？** 对泊车，最值得语言化/可验证化的可能不是逐点 `(x,y)`，而是 `{目标车位, 入库方向, 首段前进或倒车, 允许换挡次数, 安全间距偏好, 终止条件}`；低层连续段仍由 SunnyParking/YUKUIv2 式 trajectory generator 与运动学安全层处理。

#### 6.5.5 可证伪的后续实验

若要证明 SunnyParking 的改动真正有价值，可在 ParkingE2E 的实车闭环协议上做一个 2 × 2 消融，避免将目标表示、网络容量和控制器变化混为一谈：

| Goal interface | Action interface | 要回答的问题 |
|---|---|---|
| BEV heatmap | trajectory only | ParkingE2E 基线 |
| Fourier continuous slot pose | trajectory only | 连续目标是否减少 cell-boundary/终姿误差？ |
| BEV heatmap | trajectory + direction state | 显式 forward/reverse 是否改善 multi-shot？ |
| Fourier continuous slot pose | trajectory + direction state | 两种接口是否互补？ |

四组必须使用同一 perception backbone、trajectory horizon、controller、训练/测试车位划分和计算预算。除 L2/heading/shift-point error 外，还应报告：入位成功率、最终 pose 误差、换挡数、换挡前零速满足率、最小间距、碰撞/卡死率，以及对初始 pose 和 slot pose 的连续微扰曲线。这样才能把“更连续的目标表示”从漂亮的 encoding 动机，推进成闭环可验证的规划结论。

## 7. 与停车和 VLA 路线的关系

### 7.1 纯连续回归到分层 action representation

```text
E2E Parking: images → direct controls
        ↓
ParkingE2E / TransParking: images + slot → continuous trajectory
        ↓
SunnyParking: trajectory + forward/reverse state
        ↓
YUKUIv2: motion-transition key point + diffusion segment
        ↓
possible VLA parking: verifiable maneuver/meta-action + constrained trajectory generator
```

SunnyParking 处在关键的中间位置：它还不是 diffusion/VLA，却建立了后续 generation model 需要的低熵、可验证 maneuver interface。YUKUIv2 将状态切换进一步变成 key points，再为每段连续运动使用 diffusion；DriveMA 则提供更一般的“轨迹—meta-action 可逆验证”思路。

### 7.2 与传统规划的互补方式

最合理的工程组合不是用网络取代一切，而是：

```text
perception + slot goal
        ↓
SunnyParking-style maneuver proposal: {forward/reverse, shift points}
        ↓
continuous segment generator
        ↓
kinematic projection / collision checker / MPC
        ↓
closed-loop execution and recovery
```

这里学习系统决定人类风格、多模态意图和需要几把；传统系统对每段轨迹施加硬约束并在出错后提供恢复。实验应分别测 proposal 对不对、投影改了多少、最终闭环是否成功，避免把安全层的收益错误归因给网络。

## 8. 可能的失败模式

1. **风格偏置替代最优性**：训练集中 4-shot 多，模型把可一把完成的任务预测为多把；低 imitation loss 不代表低时间、低换挡或高舒适性代价。
2. **状态-轨迹软耦合不足**：motion branch 从 trajectory hidden state 读取特征，但没有强制速度符号、gear 和轨迹弧长的一致性。
3. **停顿状态未显式生成**：stationary 虽出现在原始标注，decoder 却只输出二元 direction；换挡前必须停车的物理语义可能被隐式且不稳定地处理。
4. **开环 exposure bias**：当前点/当前状态偏离专家后，模型未被证实能够重规划或从错误换挡恢复。
5. **静态场景过拟合**：固定 CARLA 地图、16 个车位和静态障碍无法覆盖动态让行、遮挡、雨夜或定位误差。
6. **目标编码并不等于目标可达性**：slot pose 的连续表达可降低量化误差，却不能保证当前起点下存在无碰撞、满足转弯半径的解。

## 9. 复现与扩展：怎样把论文命题做扎实

### 9.1 最小可证伪实验

保留同一视觉 encoder、相同训练数据与相同 controller，只改变 planning interface：

1. trajectory-only regression；
2. trajectory + two-class motion state；
3. + shift-aware smoothness；
4. + Fourier goal fusion；
5. + gear/zero-speed/collision/curvature projection。

每一组至少三训练 seed，并在未见起点、未见车位、目标 pose 扰动和感知噪声下执行 CARLA 闭环。这样才能回答“motion state 是否真的改善多把泊车”，而不是只改善同分布轨迹拟合。

### 9.2 指标必须分层

| 层级 | 至少报告 |
|---|---|
| 表示/预测 | trajectory L2、Hausdorff、heading、motion accuracy、shift-point error |
| 运动学 | 速度符号-gear 一致率、换挡前零速率、最大曲率/曲率变化违规率 |
| 安全与任务 | success、最终 pose/heading 误差、碰撞、最小间距、off-road/越界、卡死 |
| 行为质量 | 换挡数、时长、路径长度、jerk、与专家风格的分布距离 |
| 鲁棒性 | 起点/目标扰动切片、动态障碍、sensor dropout、闭环 recovery |
| 工程 | 端到端 latency、控制频率、failure fallback 覆盖率 |

### 9.3 一个有价值的下一代模型

可把 SunnyParking 的状态序列提升为：

$$
z_k=(\text{gear},\text{intent},\text{subgoal},\text{termination}),
$$

并生成分段轨迹：

$$
\tau_k\sim p_\theta(\tau_k\mid o, S, z_k),\qquad
\tau_k\leftarrow\Pi_{\text{kinematic,safe}}(\tau_k).
$$

其中 $z_k$ 可由演示自动投影、规则验证或人工语言指定；$\Pi$ 负责运动学与碰撞投影。相比整段 `$\tau$` 回归，它允许模型保留“该倒车入位还是前进修正”的多模态，又让连续轨迹不受粗粒度 action token 的量化限制。

## 10. 原文精读路线

1. **Abstract、Figure 1、Introduction**：确认作者批判的是 pure geometric regression，而非泛化地否定学习式规划。
2. **Figure 2、Section III-A**：看输入、输出与 YUKUI 双分支；注意模型实际不是控制输出。
3. **Section III-B/C、Figure 6**：从目标 heatmap 的量化缺陷读到 Fourier target query fusion；再区分“可视化线索”和实证结论。
4. **Section III-D/E、Figure 3**：画出 trajectory hidden feature 流向 motion branch，以及 shift-aware smoothness 的 mask。
5. **Table I-II、Figure 5**：不只读最佳 L2；逐项检查 Hausdorff、AHE、换挡点误差、复杂度和 over-shift 样例。
6. **Appendix A、Figure 7-10**：核验 CARLA 静态场景、起点覆盖、G29 人类采集、成功条件和 1-4-shot 分布。
7. **Conclusion**：明确记录作者承认的下一步：动态参与者、复杂真实场景与 closed-loop 验证。

## 11. 最终评价

SunnyParking 最值得保留的不是某个 Transformer 细节，而是它把 multi-shot parking 的行动结构说清楚：

```text
连续 waypoint 回归
    → 容易把换挡边界藏在平均误差里
    → 显式预测前进/倒车状态并定位切换点
    → 让 maneuver 成为可验证、可统计、可被下一层生成模型条件化的变量
    → 但仍必须用运动学投影和交互式闭环证明它真的能停车
```

对泊车规划研究最实际的启发是：**不要只比较“轨迹是否贴近演示”；还要把方向、换挡、停止、子目标和恢复当作 action representation 的一部分，并在闭环中验证这些变量是否真正提高完成率与安全性。**
