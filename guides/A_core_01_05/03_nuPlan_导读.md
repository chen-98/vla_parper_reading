# nuPlan 导读

> **论文**：nuPlan: A Closed-loop ML-based Planning Benchmark for Autonomous Vehicles  
> **作者**：Holger Caesar 等 9 人  
> **年份**：2021（arXiv v4: 2022）  
> **原文**：[本地 PDF](../../papers/A_core/03_nuPlan_2021.pdf) · [arXiv](https://arxiv.org/abs/2106.11810) · [项目页](https://nuplan.org/nuplan)  
> **建议阅读时间**：25-35 分钟

## 先记住一句话

nuPlan 的贡献不是提出一个 planner，而是把问题重新定义清楚：**规划需要目标、长期闭环交互和专用安全/舒适/进度指标，不能沿用 motion prediction 的短时 open-loop L2 排名。**

## 为什么它被放在 A_core

在 nuPlan 之前，大量 learning-based planning 工作借用预测数据集与 ADE/FDE。这样会产生三个错位：

1. 没有 route/goal，路口左转与右转无法判断谁“正确”；
2. 多个行为都合理时，离人类日志更远不等于规划更差；
3. open-loop 中 ego 动作不会改变后续状态，无法观察漂移与交互后果。

Figure 1 用三个例子把这三件事讲透：目标歧义、多模态行为和交互缺失。这一页比具体数据规模更值得精读。

## Benchmark 的系统接口

参赛 planner 在每个时刻接收结构化轨迹/地图信息，或在特定任务中接收 raw sensor，输出 ego 未来位置与 heading。统一 controller 和 motion model 跟踪该轨迹，然后按最终驶过的轨迹打分。

```text
scenario + route goal + observations
                 ↓
            user planner
                 ↓
      planned position + heading
                 ↓
 controller + ego motion model
                 ↓
 closed-loop rollout + metrics
```

所以 nuPlan 的 action representation 是 **连续 ego trajectory**。它评价的是 planner，不要求所有方法采用相同内部网络，也不等价于 raw-camera E2E benchmark。

## 三种评测任务

### Open-loop

逐帧输出轨迹并与日志比较，但不执行，不考虑交互。适合快速调试和 imitation fidelity，不足以证明规划安全。

### Non-reactive closed-loop

ego 按 planner 轨迹前进，其他交通参与者沿真实日志轨迹重放。可以暴露 ego 的累积偏差，但如果 ego 改变行为，其他车辆不会响应，可能制造不合理碰撞或错过真实让行。

### Reactive closed-loop

ego 与其他 agent 都通过行为模型更新，更接近交互式规划评价。它的可信度又取决于 traffic-agent model 是否合理。

论文特别指出：ego 偏离日志会产生新的相机/LiDAR 视角，而该版本 benchmark 不做 sensor warping 或 novel-view synthesis。因此结构化 planner 更适合完整 closed-loop；raw-sensor E2E 的闭环仍存在观测生成难题。

## 数据与场景覆盖

论文提出约 1500 小时、四个城市的数据：Boston、Pittsburgh、Las Vegas、Singapore，并提供地图、自动标注轨迹、定位、转向输入以及部分传感器数据。场景标签包括并线、换道、受保护/无保护转弯、行人/骑行者交互、双排停车、停止控制路口和施工区等。

这些标签的价值不只是筛数据，而是允许 scenario-specific metrics。全局总分可能掩盖某类规划能力，按场景切片才能知道 planner 到底在什么地方失效。

## 指标框架

论文将指标分成 common metrics 与 scenario-based metrics：

- **交通规则/安全**：碰撞、越界、time gap、TTC、不同通过距离下的相对速度；
- **human driving similarity**：速度、停车位置、横向位置与人工轨迹的差异；
- **vehicle dynamics**：加速度、jerk、steering rate、振荡和可行性阈值；
- **goal achievement**：沿路线向目标的进度；
- **场景指标**：换道的前后车 time gap、行人/骑行者通过速度、路权决策等。

规划工程上的重要思想是：安全、进度、舒适与 imitation 不是一个指标。一个保守到永远停车的 planner 可能很安全，但没有完成任务；一个完全模仿日志的 planner 在不同交互分支中也未必合理。

## 这篇短文的局限

- 只有 5 页，本质上是 benchmark 蓝图，很多后来实际 devkit、scenario sampling 和评分细节不在文中。
- 文中指标聚合方式仍邀请社区讨论；不要把早期描述当成当前实现的最终规范。
- non-reactive 与 reactive closed-loop 各有偏差，不能笼统写成“做了 closed-loop 所以可信”。
- 自动标注、agent model、controller 和 motion model 都可能影响 planner 排名。
- 它主要评价规划，不是对 perception、prediction、planning 全栈真实性的一次性证明。

## 与其他论文的关系

ChauffeurNet 已展示 open-loop L2 与闭环表现可能反向；nuPlan 把这个经验提升为公共 benchmark 设计。TransFuser/TCP 使用 CARLA reactive simulation，关注 raw-sensor E2E；NAVSIM 后来选择低成本 non-reactive simulation；Bench2Drive 强化 CARLA 多能力闭环；WOD-E2E 则补足真实数据与长尾场景。读这些 benchmark 时应沿用 nuPlan 的问题拆解，而不是直接比较总分。

对泊车 benchmark，同样需要从“轨迹离专家多近”转向：是否入位、碰撞/最小间距、换挡次数、时间、舒适性、运动学可行性、multi-shot 恢复和动态障碍交互。

## 建议精读路线

1. Figure 1 + Introduction：理解 prediction benchmark 为什么不适合 planning。
2. Section 3：关注城市/场景多样性，而非只记 1500 小时。
3. Section 4.1-4.2：画清 open-loop、non-reactive、reactive 三种数据流。
4. Section 4.3：把每个指标归入安全、舒适、进度或 imitation。
5. 回看自己的 planner 指标，标出哪些失败类型目前完全不可见。

## 读完后应能回答

- 为什么一条与日志不同的轨迹可能同样正确，甚至更安全？
- non-reactive closed-loop 比 open-loop 多验证了什么，又引入了什么伪影？
- reactive agent model 的错误会如何改变 planner 排名？
- controller 跟踪误差应该归因给 planner、controller，还是统一系统？
- 如果做多把泊车 benchmark，主分数应如何避免“少换挡但危险”和“绝对安全但不入位”两个极端？

## 复现建议

不要复现论文模型，因为它没有提出模型。应复现的是评测纪律：把同一 planner 同时放入 open-loop、non-reactive closed-loop 和可交互闭环，按安全、进度、舒适、规则和场景切片报告。对任何新模型，先写 evaluation contract，再开始调网络。
