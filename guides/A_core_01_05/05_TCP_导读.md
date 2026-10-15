# TCP 导读

> **论文**：Trajectory-guided Control Prediction for End-to-end Autonomous Driving: A Simple yet Strong Baseline  
> **作者**：Penghao Wu, Xiaosong Jia, Li Chen, Junchi Yan, Hongyang Li, Yu Qiao  
> **会议**：NeurIPS 2022  
> **原文**：[本地 PDF](../../papers/A_core/05_TCP_2022.pdf) · [会议页面](https://proceedings.neurips.cc/paper_files/paper/2022/hash/286a371d8a0a559281f682f8fbf89834-Abstract-Conference.html) · [代码](https://github.com/OpenPerceptionX/TCP)  
> **建议阅读时间**：35-45 分钟

## 先记住一句话

TCP 的出发点是：**trajectory output 与 direct control 各有互补优势，因此不应二选一；让轨迹分支指导多步控制分支，再按驾驶情境融合两种输出。**

## 它在规划链路中的位置

模型输入为单目 RGB、车速、高层导航命令和局部目标点。共享 encoder 后分为：

- trajectory branch：自回归预测未来 waypoint，再经 PID 得到控制；
- control branch：直接预测当前与未来多步 control distribution；
- situation-based fusion：根据是否转弯，为两个分支的控制结果设置不同权重。

因此 TCP 的 action representation 是 **hybrid：continuous trajectory + direct control distribution**。它既是 planner，也是 control policy；但最终执行动作仍含手工融合逻辑。

## 为什么要同时保留两种表示

论文的经验判断是：

- 轨迹分支具有未来视野，车辆碰撞更少，但简单 PID 在转弯时可能跟踪不准，容易碰撞道路结构、越界或卡住；
- 控制分支直接优化 steering/throttle/brake，转弯更灵活，但只预测当前动作时反应偏晚，车辆碰撞更多。

Table 2 验证了这个差异。TCP 不把 trajectory 只当辅助标签，而是让它参与 control feature aggregation，并在最终动作层继续保留两条路径。

## 架构核心

### 1. 轨迹规划分支

图像特征经 average pooling，与速度、导航命令和目标点的 measurement feature 拼接；GRU 自回归生成 K 个 waypoint。相邻 waypoint 的长度与方向分别交给纵向和横向 PID，产生 `a_traj`。

### 2. 多步控制分支

控制分支不是只输出当前动作，而是预测 `a_t ... a_t+K`。GRU temporal module 接收当前 feature 与预测动作，隐式模拟环境和 ego 随动作变化后的状态。论文将它描述为粗粒度 feature-space simulator，但它没有显式 world reconstruction，也不应等同于后来的 world model。

控制动作用 Beta distribution 参数化，训练时最小化与 expert control distribution 的 KL divergence。当前步损失权重高于平均后的未来多步损失。

### 3. Trajectory-guided attention

在未来第 t 步，轨迹 GRU 与控制 GRU 的 hidden states 共同生成 attention map，对二维图像 feature map 重新聚合。直觉是：预测 ego 将出现在哪里，可以告诉控制分支未来应该关注路面边界、车辆或转弯区域中的哪一部分。

Figure 3/4 中，轨迹不是仅通过 waypoint loss 提供 regularization，而是逐步影响 control branch 的视觉注意力。

### 4. Privileged expert 与辅助监督

数据由 Roach 采集；Roach 是使用道路、路线、车辆、行人、交通灯等 privileged BEV 的 RL expert。学生除轨迹与控制监督外，还蒸馏 expert latent feature、预测 expert value，并增加当前速度预测。

所以 TCP 的效果不能简单归因于“双分支”：privileged expert 的数据质量、feature/value distillation 也是重要组成部分。

### 5. Situation-based fusion

两个分支分别产生控制后，根据车辆是否转弯决定谁占更高权重。论文中 `alpha=0.3`，转弯偏向 control，其他场景偏向 trajectory。

这是有效但粗粒度的 meta-controller。它还不是学习式 gating，也没有依据不确定性、风险或场景交互动态自适应选择。

## 实验结论

模型使用 CARLA 8 个公开城镇生成的 42 万帧数据；消融用其中 4 个城镇的 18.9 万帧。公开 Leaderboard（论文访问时间为 2022 年 5 月）上，单模型 TCP 的 Driving Score 为 69.714，ensemble 为 75.137，仅使用单目相机。

Table 3 的组件消融很清晰：

| 配置 | Driving Score |
|---|---:|
| control baseline | 32.45 |
| + trajectory task | 34.98 |
| + temporal multi-step | 42.87 |
| + trajectory attention | 46.08 |
| + situation fusion | 57.01 |

最大增益来自 multi-step temporal design 与最终融合，而不是单纯添加 trajectory auxiliary loss。共享 encoder 的 TCP 在参数量与 FLOPs 上也明显低于简单 ensemble，并可达到约 125.7 FPS；ensemble 分数更高，但计算量约为三倍。

## 局限与阅读警惕

- 融合判据只看是否转弯，缺少风险、置信度与复杂交互建模。
- temporal module 只在 latent feature 中滚动，没有新的传感观测或显式其他 agent dynamics。
- 未来 control 监督来自 expert rollout；闭环时环境会因自身动作改变，仍存在预测分布偏移。
- 结果集中于 CARLA，没有实车和跨仿真验证。
- 单目模型的高分依赖 privileged RL expert、蒸馏损失、PID 与融合实现，不能只复刻 Figure 2。
- 两种分支可能给出不一致动作；固定加权能缓解，但没有形式化安全保证。

## 与前后工作的关系

TransFuser 重点解决 RGB/LiDAR scene feature fusion，TCP 重点解决 trajectory/control output fusion，两者是平行方向。TCP 继承 LBC 式 privileged supervision，但教师换成 RL policy，并额外蒸馏 feature/value。后来的 unified planner、多模态生成和 VLA 会继续面对同一个问题：语义更强的上层表示如何稳定落到实时控制。

对泊车而言，TCP 的关键启发不是照搬“转弯/非转弯”规则，而是建立层级互补：maneuver/trajectory branch 提供长时与换挡结构，control branch 处理短时跟踪与扰动；gating 应根据 gear、曲率、碰撞风险、tracking error 和 maneuver phase 学习或验证。

## 建议精读路线

1. Introduction 的 control-only vs trajectory-only 失败案例。
2. Figure 2：先画出共享 encoder、两分支、两种控制和 fusion。
3. Section 3.2.2 + Figure 3：弄清 temporal GRU 与 trajectory-guided attention。
4. Section 3.3：区分 waypoint、Beta control、feature/value 辅助损失。
5. Table 2-4：看表示互补、组件增益与计算成本。
6. Figure 5/融合权重实验：理解手工 gating 的脆弱性。

## 读完后应能回答

- trajectory-only 与 control-only 为什么会出现不同类型的闭环错误？
- 预测未来 control 是否真的建模了环境，还是只是一种辅助时序监督？
- trajectory-guided attention 如何把“未来位置”转换为当前视觉关注区域？
- TCP 的性能应分别归因给 teacher、双分支、temporal module、attention 还是 fusion？
- 在多把泊车中，何时应信任轨迹分支，何时应让 control/residual policy 接管？

## 复现建议

建议复现。先固定同一 expert、encoder、PID 和训练数据，做 trajectory-only、control-only、MTL、trajectory-guided control、learned/handcrafted gating 五级对照。不要只报告总 Driving Score；需按直行、转弯、动态避障、恢复、低速跟踪分场景统计。泊车版本可将分支改为 multi-shot trajectory + short-horizon control，并用 gear/motion state 替代粗粒度 turning flag。
