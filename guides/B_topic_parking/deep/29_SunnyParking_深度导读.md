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

## 3. 连续目标表示：从车位 pose 到 target-aware BEV

### 3.1 为什么 rasterized goal 不够

若把目标车位中心和方向绘制在 0.1 m/pixel 的 BEV heatmap 中，位置在栅格边界附近发生小幅移动时，输入可能完全不变或突然跳一个 pixel。对一般车道级规划，这种近似未必致命；对窄车位终姿与换挡边界，10 cm 离散化会污染目标条件。

SunnyParking 将归一化位置映射到多频 Fourier features：

$$
\gamma_{pos}(p')=[\sin(2^0p'),\cos(2^0p'),\ldots,
\sin(2^{L-1}p'),\cos(2^{L-1}p')],\quad L=12,
$$

并将 $x'$、$y'$ 与其 Fourier features 连接；yaw 以 $[\sin\theta,\cos\theta]$ 表示，避免角度 $-\pi/\pi$ 不连续。论文声称该频率设置的理论分辨率约 1.2 cm，并给出 1-2 mm 的有效精度说法。这个数值反映的是 **编码表达能力**，而不是端到端实际停车误差。

### 3.2 Cross-domain target fusion

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
